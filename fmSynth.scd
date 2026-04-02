(
// this instrument requires the installations of SC3 plugins: https://supercollider.github.io/sc3-plugins/
{
	arg interface, port, out, mode;
	var instrument;
	instrument = Dictionary.new;

	////////////////////////////////
	//2. initialize global variables
	////////////////////////////////

	// declare a function for initializing variables
	instrument.add(\initVariables -> {

		// interface  name, receiving port, audio output bus, mono/stereo
		instrument.add(\interface ->  interface);

		// default mode is stereo
		instrument.add(\audioChan -> (mode != "mono").if(2,1));

		// List of DMI control parameters [OSC address, size, mapped or not]   TBC!!!
		instrument.add(\tStickParam -> [
			["/raw/capsense"                 ,      30, "mapped"],
			["/raw/fsr"                      ,       1, "mapped"],
			["/raw/accl"                     ,       3, "mapped"],
			["/raw/gyro"                     ,       3, "mapped"],
			["/raw/magn"                     ,       3,         ],
			["/instrument/shakexyz"          ,       3, "mapped"],
			["/instrument/squeeze"           ,       1,         ],
			["/instrument/touch/all"         ,       1,         ],
			["/instrument/touch/top"         ,       1,         ],
			["/instrument/touch/middle"      ,       1,         ],
			["/instrument/touch/bottom"      ,       1,         ],
			["/instrument/touch/discrete"    ,      30,         ],
			["/instrument/jabxyz"            ,       3, "mapped"],
			["/instrument/brush"             ,       1,         ],
			["/instrument/multibrush"        ,       4,         ],
			["/instrument/rub"               ,       1,         ],
			["/instrument/multirub"          ,       4,         ],
			["/instrument/button/count"      ,       1,         ],
			["/instrument/button/tap"        ,       1,         ],
			["/instrument/button/ttap"       ,       1,         ],
			["/battery/percentage"           ,       1,         ],
			["/battery/current"              ,       1,         ],
			["/battery/timetoempty"          ,       1,         ],
			["/battery/voltage"              ,       1,         ],
			["/orientation"                  ,       4,         ],
			["/ypr"                          ,       3,         ]
		]);

		// List of sound synthesis control parameters [, [intial values], mapped or not]
		instrument.add(\synthParam -> [
			// ["c"             ,                   [ 0 ],         ], // SIZE???
			// ["cm"            ,                   [ 0 ],         ], // Mapped???
			// ["index"         ,                   [ 0 ],         ],
			// ["amp"           ,                 [ 0.4 ],         ],
			// ["atk"           ,                   [ 0 ],         ],
			// ["rel"           ,                   [ 0 ],         ],
			// ["atkCrv"        ,                   [ 0 ],         ],
			// ["relCrv"        ,                   [ 0 ],         ],
			// ["gate"          ,                   [ 0 ],         ],
			// ["lag"           ,                 [ 0.1 ],         ],
			// ["param1"        ,                   [ 0 ],         ],
			// ["param1"        ,                   [ 0 ],         ],
			// ["trigger"       ,                   [ 0 ],         ], // DIFFERENCIATE BTW Synth arguments
			// ["param1"        ,                   [ 0 ],         ], // AND intermediate parameters...
			// ["octave"        ,                   [ 0 ],         ],
			// ["param2"        , [ 1, 1, 1, 1, 1, 1, 1 ], "mapped"],
			// ["param3"        ,                [ 0.33 ], "mapped"],
		]);



		// Turn on/off calibration
		instrument.add(\toggle -> 0);

		// Dictionnary containing calibration results
		instrument.add(\calibrationVals -> Dictionary.with(*[
			\fsr -> [0, 4095],
			\shakeThresh -> [0, 2],
			\shakeMax -> [0, 6]
		]));

		// Emulate Gen4 T-Stick with only 16 capsense....
		instrument.add(\capsense -> Array.fill(16, 0));

		// default amp value for FM synth
		instrument.add(\fmAmp -> (-18).dbamp);

		// Maximum detune coefficient
		instrument.add(\devMax -> 3.0);

		// Array containing instances of FM synths
		instrument.add(\synthArray -> Array.fill(128, nil));

		instrument.add(\cmArray -> [1/9, 1/8, 1/7, 1/6, 1/5, 2/9, 2/8, 2/7, 2/6, 3/8, 2/5, 3/7]); // À REVISITER TAILLE BODY (11 ou 12...)

		instrument.add(\oct -> [1/2, 1, 2]);

		instrument.add(\root -> (110 * [1, 2, 6/5, 12/5, 4/3, 8/3, 3/2, 6/2, 5/3, 10/3]) ); //Hz UTILISÉ???

		// Triads
		instrument.add(\chords -> [[110, 110, 110], [110, 220, 330], [110, 165, 220], 110*[4/3, 5/3, 10/3], 110*[6/5, 3/2, 2], 110*[4/3, 2, 12/5], 110*[4/3, 6/2, 10/3]]);
		instrument.add(\chordsWeight -> [1, 5, 8, 3, 5, 3, 5].normalizeSum);

		//
		instrument.add(\notes -> Array.fill(11, instrument[\root][0])); // 11 capsense are used for triggering Synth REWORK SMARTER SIZE body dans \touch

		instrument.add(\synthTrig -> Array.fill( instrument[\cmArray].size, 0)); // PAS NÉCESSAIRE DE MAPPER SUR UN BUS DE CONTRÔLE
		instrument.add(\fFreq -> 15000);
		instrument.add(\fcMin -> 150);
		instrument.add(\fcMax -> 20000);


		// Dictionary of SynthDef arguments TBC À METTRE À JOUR
		instrument.add(\synthDefParam -> instrument[\synthParam].collect{
			arg item, i;
			var dic;
			if(item[2] == "mapped") {
				// create a Dictionary for each argument that is mapped
				dic = Dictionary();
				// argument name
				dic.add(\arg -> item[0]);
				// argument initial value(s)
				dic.add(\init -> item[1]);
			}
		});
		instrument[\synthDefParam] = instrument[\synthDefParam].reject({|item| item.isNil});
		(interface + ": Variables initalized").postln;
	});
	// end of \initVariables function

	////////////////////////////////
	//3. define piece-specific functions
	////////////////////////////////

	// declare a function for specific functions
	instrument.add(\specificFunctions -> {

		// function to express a sideband frequency as a string representing a fraction of carrier frequency C
		instrument.add(\cFraction -> {
			arg f;
			f.asFraction[0].asString ++ ":" ++ f.asFraction[1];
		});


		// function returning the Normal Form of a C:M ratio
		instrument.add(\fmNFcm -> {
			arg cm=1/1;
			var c=1, m=1;
			c = cm.asFraction[0];
			m = cm.asFraction[1];
			// C:M ratio is in its Normal Form if M >= 2*C or C:M = 1:1
			while { and( m < (2*c), c/m != 1 ) } { c = abs(c-m)};
			instrument[\cFraction].value(c/m);
		});

		// function returning the carrier frequency corresponding to requested fundamental and C:M ratio
		instrument.add(\fmCarrier -> {
			arg ffund=100, cm=1/1;
			var nfcm=1/1, fcarr=100;
			nfcm = instrument[\fmNFcm].value(cm);
			nfcm = nfcm.split($:);
			nfcm = nfcm[0].asInteger / nfcm[1].asInteger;
			ffund * cm / nfcm;
		});

		// function returning an array of notes (Hz)
		//
		instrument.add(\notesConstruct -> {
			arg chord;
			var array;
			array = chord.stutter(4);
			array.removeAt(array.size - 1);
			array.sort.reverse;
		});

		// create buffer for FSR mapping
		instrument.add(\makeBuffers -> {
			instrument.add(
				\fsrBuf -> Buffer.alloc(s, 1024);
			);
			"".postln;"--------------------------------".postln; (interface + ": Buffers created").postln;"--------------------------------".postln;
		});

		// Calibration Function
		instrument.add(\calibrationFunc -> {
			arg onOff=0, bus=0, dict=nil, key=nil;
			var arr=[], val, minVal=4095, maxVal=0;

			if(onOff == 1) {
				instrument.add(\calibRoutine -> Routine{
					loop{
						val = bus.getSynchronous;

						if( arr.size < 10,
							{
								arr = arr.add(val);
							},{
								arr = arr.add(val);
								arr = arr.shift(-1);
								arr = arr.keep(10);
							}
						);
						minVal = minVal.min(arr.mean);
						maxVal = maxVal.max(arr.mean);
						(key ++ " min value: " ++ minVal.round(0.001) ++ " - " ++ key ++ " max value: " ++ maxVal.round(0.001)).postln;

						dict[key] = [minVal, maxVal];
						0.01.wait;
					}
				});
				instrument[\calibRoutine].play;
			}{
				instrument[\calibRoutine].stop;
			};
		});

		// Create control busses when server has booted   ||| TBC |||
		instrument.add(\makeBusses -> {
			var bus = 0;
			// Dictionary of busses, keys are DMI source names ||| NOT USED YET |||
			instrument.add(\busDmi -> Dictionary.new);
			// loop through all interface control signals
			instrument[\tStickParam].do({
				arg item;
				if(item[2] == "mapped") {
					// create control busses, number of channels from \tStickParam array
					instrument[\busDmi].add((interface ++ item[0]) -> Bus.control(s, item[1].asInteger));
					// update total number of busses created
					bus = bus + item[1].asInteger;
				};
			});

			(interface ++" interface control busses: " ++ bus.asString).postln;

			// Dictionary of busses, keys are Synth arguments names
			bus = 0;
			instrument.add(\busSynth -> Dictionary.new);
			// instrument[\arrayKey].value(instrument[\synthDefParam], \arg).do({
			// 	arg item, i;
			// 	// bus number of channels is the size of the parameter initial value
			// 	instrument[\busSynth].add(item -> Bus.control(s, instrument[\synthDefParam][i][\init].size));
			// 	bus = bus + instrument[\synthDefParam][i][\init].size;
			// });

			instrument[\busSynth].add(\busCm -> Bus.control(s, instrument[\cmArray].size));
			instrument[\busSynth].add(\busAtkRel -> Bus.control(s, 4)); // atk time, curve, rel time, curve
			instrument[\busSynth].add(\busIndex -> Bus.control(s, 1));
			instrument[\busSynth].add(\busModIndex -> Bus.control(s, instrument[\cmArray].size));
			instrument[\busSynth].add(\gateBus -> Bus.control(s, 1)); // TBC IN DETAIL???
			instrument[\busSynth].add(\busAmp -> Bus.control(s, 1)); // INCREASE SIZE ??? map each synth on his amp bus

			// Initialize c/m ratio busses
			instrument[\busSynth][\busCm].numChannels.do({|i| instrument[\busSynth][\busCm].subBus(i).set( instrument[\cmArray][i])});

			// Audio busses for FX
			instrument[\busSynth].add(\fx -> Bus.audio(s,instrument[\audioChan]));
			// instrument[\busSynth].add(\lim -> Bus.audio(s,instrument[\audioChan]));
			(interface  ++" Synth control busses: "++ bus.asString).postln;
		});

		// Cretate Synth mapping the interface control busses to sound parameters control busses
		instrument.add(\makeBusMappings -> {
			s.bind({
				instrument.add(\mappingGrp -> Group.new);
				// {
				// 	// mapping for Synth parameter bufPos (grain position in the buffer)
				// 	var mapBufPos;
				// 	mapBufPos = In.kr(instrument[\busDmi][instrument[\interface] ++ "/raw/accl"].subBus(0), 1);
				// 	mapBufPos = mapBufPos.lincurve(-10, 10, 0, 1, 0, nil);
				// 	Out.kr(instrument[\busSynth]["param1"], mapBufPos);
				// }.play(instrument[\mappingGrp]);
				//
				// {
				// 	// mapping for Synth parameter gainLow, gainMid, gainHigh
				// 	var mapGainLow, mapGainMid, mapGainHigh, gyro;
				// 	gyro = In.kr(instrument[\busDmi][instrument[\interface] ++ "/raw/gyro"], 3);
				// 	mapGainLow = gyro[2].abs * 2;
				// 	mapGainMid = gyro[0] * 8;
				// 	mapGainHigh = gyro[1] * 6;
				// 	Out.kr(instrument[\busSynth]["gainLow"],mapGainLow);
				// 	Out.kr(instrument[\busSynth]["gainMid"], mapGainMid);
				// 	Out.kr(instrument[\busSynth]["gainHigh"], mapGainHigh);
				// }.play(instrument[\mappingGrp]);
				//
			})
		});

		// Create audio Synth
		instrument.add(\makeNodes -> {
			s.bind({
				instrument.add(\mainGrp -> Group.new);
				instrument.add(\fxGrp -> Group.after(instrument[\mainGrp]));
				instrument.add(\limGrp -> Group.after(instrument[\fxGrp]));

				// Synth modulating each touch C/M ratio
				instrument.add(\modulatorCM -> instrument[\busSynth][\busCm].numChannels.collect{
					arg i;
					Synth(\modulatorCm, [\out, instrument[\busSynth][\busCm].subBus(i), \cm, instrument[\cmArray][i]], instrument[\mainGrp]);
				});

				// Synth modulating each index
				instrument.add(\modulatorIndex -> instrument[\busSynth][\busModIndex].numChannels.collect{
					arg i;
					Synth(\modulatorIndex, [\out, instrument[\busSynth][\busModIndex].subBus(i), \dev, 1], instrument[\mainGrp]);
				});

				// low-pass Synth
				instrument.add(\lpfSynth -> Synth(\lpf, [
					\in, instrument[\busSynth][\fx],
					\fFreq, instrument[\fFreq],
					\rq, 0.5,
				], instrument[\fxGrp]));

				//
				// Schmidt trigger VÉRIFIER!!!!
				instrument.add(\schmidt -> Synth(\schmidtEnv, [
					\in, instrument[\busSynth][\gateBus],
					\out, instrument[\busSynth][\busAmp],
					\lowT, 0.01,
					\highT, 0.25, // threshold of Schmidt trigger WHY???
					\atk, 0.1,
					\relTune, 1,
					\release, 1
				], instrument[\lpfSynth], \addBefore));

				// stereo chorus Synth
				instrument.add(\chorusSynth -> Synth(\stereoChorus, [
					\in, instrument[\busSynth][\fx],
					\mix, 0
				], instrument[\lpfSynth], \addAfter));

				// reverb Synth (tail of the fx group)
				instrument.add(\revSynth -> Synth.tail(instrument[\fxGrp], [\reverbMono, \reverbStereo][instrument[\audioChan] - 1], [
					\in, instrument[\busSynth][\fx],
					\mix, 0.33,
					\room, 0.5,
					\damp, 0.2,
				], instrument[\fxGrp]));

				// limiter Synth -> declared in main SC file
				// instrument.add(\limitSynth -> Synth(\comp, [
				instrument.add(\limitSynth -> Synth([\compMono, \compStereo][instrument[\audioChan] - 1], [
					\in, instrument[\busSynth][\fx],
					\thesh, -3.dbamp,
					\out, out
				], instrument[\limGrp]));
			});
			"--------------------------------".postln;(interface ++ ": Nodes created").postln;"--------------------------------".postln;
		});

		// mapping of control busses on synth control parameters
		instrument.add(\makeMaps -> {
			// Wait to make sure Synth are created
			(interface ++ ": Creating mappings").postln;
			32.do{0.05.wait; "-".post;};
			"".postln;
			s.bind({

				// // mappings of \granulator
				// instrument[\synth].map(\dens, instrument[\busSynth]["dens"]);
				// // ~synth.map(\sync, ~busSynth["sync"]);
				// instrument[\synth].map(\gDur, instrument[\busSynth]["gDur"]);
				// // ~synth.map(\durDev, ~busSynth["durDev"]);
				//
				// // mappings of \triBand
				// instrument[\triBandSynth].map(\gainLow, instrument[\busSynth]["gainLow"]);
				//
				// // mappings of \reverb
				// instrument[\revSynth].map(\mix, instrument[\busSynth]["revMix"]);
				// instrument[\revSynth].map(\room, instrument[\busSynth]["revRoom"]);
				// instrument[\revSynth].map(\damp, instrument[\busSynth]["revDamp"]);
			});
		});

		////////////////////////////////
		// OSC message reception
		////////////////////////////////

		// FAIRE UN DICTIONNAIRE POUR ASSOCIER UN PARAM À UN BUS     // PROBLEM SEEMS TO BE IN OSCdef -> ERRORS WHEN RECEIVING DATA FROM TSTICK
		// NO ERROR AT COMPILE WHEN TSTICK IS NOT SENDING DATA
		//
		instrument.add(\makeOSCdef -> {

			// GUI for battery check
			instrument.add(\batteryOSC -> "/battery/percentage");
			instrument.add(\winBatt -> Window("/" ++ instrument[\interface] ++ instrument[\batteryOSC], Rect(10, 710, 300, 32)).front);
			instrument.add(\slider -> MultiSliderView(instrument[\winBatt], Rect(0, 0, 300, 32)));
			instrument[\slider].indexIsHorizontal_(false);
			instrument[\slider].indexThumbSize_(30);
			instrument[\slider].elasticMode_(1);
			instrument[\slider].size_(1);
			instrument[\slider].isFilled_(1);
			// Battery Check
			OSCdef((interface ++ "/batteryCheck").asSymbol, {
				arg msg;
				// (~tStick ++ " Battery: " ++ (msg[1]/100)).postln;
				defer{instrument[\slider].value_([msg[1]/100])};
			}, interface ++ instrument[\batteryOSC], recvPort: port);

			// Assign OSC data to control busses // DEACTIVATED FOR THE MOMENT... NÉCESSAIRE!!!
			// instrument[\busDmi].keys.postln;
			instrument[\busDmi].keys.do({
				arg item, i;
				item.postln;
				OSCdef(item.asSymbol, {
					arg msg;
					var val;
					// Remove the addres from the OSC message
					val = msg[1..];
					// make sure msg is an array the same size of control bus channel number (necessary?)
					val = val.reshape(instrument[\busDmi][item].numChannels);
					instrument[\busDmi][item].setn(val);
				}, item, recvPort: port);
			});

			// ////////////////////////////////
			// // Note triggering by touching Middle and Bottom of surface
			OSCdef((interface ++ "/touch"), {
				arg msg;
				var caps, trig, body, oct, capsRedux = Array.fill(15, nil);

				// capsense #16 is absent of TStick_311, and is located under the bottom endcap on TStick_191
				// only capsense  #1 to #15 are used
				// capsRedux est l'Array de 15 touches....

				caps = msg[1..30].normalize.roundUp;  /// OK avec CAPS!!!!!!!!!!
				// caps.postln;
				caps.pairsDo{
					arg a, b, i;
					capsRedux[(i/2).trunc(1)] = (a+b);
				};
				caps = capsRedux.normalize.roundUp;

				// to account for disparities between firmware versions (values [0,1] or [0, ~400])
				// values in the array are normalized and rounded up -> value is 1 when a strip is touched

				// trigs when 0 to 1 -> caps - ~fMcapsense = 1
				// instrument[\busCapsense].setn(caps); //USELESS REMOVE!
				// Map to busses controlling synth gates

				// Determine if a Synth is already playing
				// body is a subset of caps....
				body = caps[4..14];
				// WHAT IS TRIG?
				//
				trig = body - instrument[\synthTrig];

				// Octave Choice
				// oct = [1, 0, 2][caps[0] + caps[14]];

				if ( (caps[0] == 0) && (caps[1] == 0) && (caps[2] == 0) && (caps[3] == 0) ) {
					oct = instrument[\oct][0]
				} {
					if ( ((caps[0] == 1) || (caps[1] == 1)) && ((caps[2] == 0) && (caps[3] == 0)) ) {
						oct = instrument[\oct][1]
					} {
						if ( ((caps[2] == 1) || (caps[3] == 1)) && ((caps[0] == 0) && (caps[1] == 0)) ) {
							oct = instrument[\oct][2]
						} {
							oct = instrument[\oct][3.rand];
						}
					}
				};

				trig.do{
					arg item, i;
					var root;
					if((item > 0), {
						root = instrument[\notes][i]; // essayer de fixer (quoi???)
						("note: " + (root * oct).round(0.1) + " Hz").postln;
						// ~fMcmArray[i].asFraction.postln;

						instrument[\synthArray][i] = Synth(\fmChowningLag_N, [

							\c, instrument[\fmCarrier].value(root * oct * (0.25.rrand(-0.25)).midiratio, instrument[\cmArray][i]), // +/- 1/8 tone deviation

							\cm, instrument[\cmArray][i],
							\index, instrument[\busSynth][\busIndex].getSynchronous(), // samples the index value when Synth is triggered
							\inIndex, instrument[\busSynth][\busModIndex].subBus(instrument[\busSynth][\busModIndex].numChannels.rand),

							\amp, instrument[\fmAmp],
							\atk, instrument[\busSynth][\busAtkRel].subBus(0).getSynchronous() * (0.9.rrand(1.1)),
							\atkCrv, instrument[\busSynth][\busAtkRel].subBus(1).getSynchronous() * (0.9.rrand(1.1)),

							\out, instrument[\busSynth][\fx],
							// \out, 0,
						],
						// Synth in Main Group
						instrument[\mainGrp]);

						instrument[\synthArray][i].map(\cm, instrument[\busSynth][\busCm].subBus(i));
						instrument[\synthArray][i].map(\amp, instrument[\busSynth][\busAmp]);
					});
					if((item < 0), {
						instrument[\synthArray][i].set(\rel, instrument[\busSynth][\busAtkRel].subBus(2).getSynchronous() * (0.8.rrand(1.2)));
						instrument[\synthArray][i].set(\relCrv, instrument[\busSynth][\busAtkRel].subBus(3).getSynchronous() * (0.9.rrand(1.1)));
						instrument[\synthArray][i].set(\gate, 0);
					});
				};
				instrument[\capsense] = caps;
				instrument[\synthTrig] = body;
			}, interface ++ "/raw/capsense", recvPort: port);


			// ////////////////////////////////
			// // maps X acceleration to elevation and FM index control
			// // REPLACE BY
			// // 1 Synth: CALCULATE AND WRITE Index ON CONTROL BUSSES (x1)
			// // 1 Synth: CALCULATE AND WRITE atk, rel values and curves ON CONTROL BUSSES (x4)
			OSCdef(interface ++ "/acclMap", {
				arg msg;
				var accX = msg[1] * (-1); // 5 gen to investigate
				var index, atk, atkCrv, rel, relCrv;
				var sMin = -10, sMax = 10, iMin = 0, iMax = 8, iCurve = 3.5;
				var atkMin = 0.5, atkMax = 0.001, atkCurve = -3;
				var atkCrvMin = -5, atkCrvMax = 5, atkCrvCurve = 0;
				var relMin = 5, relMax = 0.1, relCurve = 0;
				var relCrvMin = 1, relCrvMax = -5, relCrvCurve = 0;
				// accX.postln;
				index = accX.lincurve(sMin, sMax, iMin, iMax, iCurve, nil);

				// ASR envelope
				atk = accX.lincurve(sMin, sMax, atkMin, atkMax, atkCurve, nil);
				atkCrv = accX.lincurve(sMin, sMax, atkCrvMin, atkCrvMax, atkCrvCurve, nil);
				rel = accX.lincurve(sMin, sMax, relMin, relMax, relCurve, -5);
				relCrv = accX.lincurve(sMin, sMax, relCrvMin, relCrvMax, relCrvCurve, nil);
				// index.postln;
				instrument[\busSynth][\busIndex].set(index);
				instrument[\busSynth][\busAtkRel].setn([atk, atkCrv, rel, relCrv]);
			}, interface ++ "/raw/accl", recvPort: port);


			// array for smoothing of last 10 values
			instrument.add(\tenVals -> Array.fill(10, 0.0));
			instrument.add(\fTemp -> instrument[\fcMax]);

			////////////////////////////////
			// maps FSR pressure RLPF
			OSCdef(interface ++ "/fsrMap", {
				arg msg;
				var fsr = msg[1];
				var mean, norm, dev, fFilt, release, fTemp, fsrThr = instrument[\calibrationVals][\fsr][1]*0.9;

				instrument[\tenVals] = instrument[\tenVals].shift(1).putFirst(fsr);
				// ~fMtenVals.postln;
				mean = (instrument[\tenVals].sum / instrument[\tenVals].size);
				// REMOVED fMaxFsr -> golbal variable (no overlap with dynamic envelope))
				instrument[\calibrationVals][\fsr][0] = instrument[\calibrationVals][\fsr][0].min(mean);

				norm = fsr.linlin(instrument[\calibrationVals][\fsr][0], instrument[\calibrationVals][\fsr][1], 0, 1); // normalized fsr value
				// ~fMbusFsr.set(norm); // NOT USED ????

				// deviation factor
				if (norm > 0.2, {
					instrument[\fsrBuf].get(norm*1023, {|val| instrument[\fTemp] = val})
				}, {
					fFilt = instrument[\fcMax]
				});
				fFilt = instrument[\fTemp];

				// Addition of activation on the gate on ~fmGateBus
				release = instrument[\tenVals].maxItem.linlin(fsrThr, instrument[\calibrationVals][\fsr][1], 2, 5);
				if(fsr > fsrThr,
					{
						instrument[\busSynth][\gateBus].set(0.4);
						("BOOST " ++ fsr).postln;
						instrument[\schmidt].set(\release, release);
						instrument[\schmidt].set(
							\level, fsr.linlin(instrument[\calibrationVals][\fsr][1]*0.9, instrument[\calibrationVals][\fsr][1], 0.2, 0.9)
						);
					},{
						instrument[\busSynth][\gateBus].set(0.0)
				});

				// ("fc " ++ fFilt).postln;
				instrument[\lpfSynth].set(\fFreq, fFilt);
			}, interface ++ "/raw/fsr", recvPort: port);


			////////////////////////////////
			// maps gyro to reverb
			instrument.add(\mvtVals -> Array.fill(100, 0.0));

			OSCdef(interface ++ "/gyroMap", {
				arg msg;
				var mvt = msg[1..3].abs.mean;
				var mix, room, damp;
				var chorus, mvtMean;

				instrument[\mvtVals] = instrument[\mvtVals].shift(1).putFirst(mvt); // last 100 values

				// ~fMmvtVals.mean.postln;
				mix = instrument[\mvtVals].mean.lincurve(0, 2, 0.2, 0.8, -3.5);
				damp = instrument[\mvtVals].mean;
				room = instrument[\mvtVals].mean.lincurve(0, 2, 0.2, 0.8, -2);
				// (mix.round(0.1) + "|" + room.round(0.1) ++ "|" + damp.round(0.1)).postln;
				instrument[\revSynth].set(\mix, mix);
				instrument[\revSynth].set(\romm, room);
				instrument[\revSynth].set(\damp, damp);
				// (2*mvt+1).lag(10).postln;
				instrument[\modulatorIndex].do{
					arg mod, i;
					mod.set(\dev, (2*instrument[\mvtVals].mean+1));
				};
				chorus = instrument[\mvtVals].mean.lincurve(0, 2, -1, 1, -4);
				// chorus.postln;
				// instrument[\chorusSynth].set(\mix, chorus); // REMETTRE!!!

			}, interface ++ "/raw/gyro", recvPort: port);


			// ////////////////////////////////
			// // maps shake to detune
			instrument.add(\numShakes -> Array.fill(10, 0.0));
			OSCdef((interface ++ "/shakeMap").asSymbol, {
				arg msg;
				var shake = msg[1..3], dev=1, shakeSmooth=0;
				// shake.postln;
				shake = shake[0..2].mean;
				// ("sh" + shake.round(0.01)).postln;

				instrument[\numShakes] = instrument[\numShakes].shift(1).putFirst(shake);
				shakeSmooth = instrument[\numShakes].mean;
				// ("smooth" + shakeSmooth.round(0.01)).postln;
				// deviation factor
				if (shake > instrument[\calibrationVals][\shakeThresh][1], {
					dev = shake.lincurve(instrument[\calibrationVals][\shakeThresh][1], instrument[\calibrationVals][\shakeMax][1], 1.0, instrument[\devMax], -1)
				}, {
					dev = 1}
				); // ajouter porteuse...
				// ("dev " ++ dev.round(0.01)).postln;
				instrument[\busSynth][\busCm].numChannels.do{
					arg  i;
					// ~fMbusCm.subBus(i).set(~fMcmArray[i] * dev);
					instrument[\modulatorCM][i].set(\dev, dev);
				};
				instrument[\busSynth][\busShake].set(shake); // USELESS REMOVE???
				instrument[\busSynth][\fMbusDev].set(dev); // USELESS REMOVE???
			}, interface ++ "/instrument/shakexyz", recvPort: port);


			////////////////////////////////
			// maps jabX to change the note
			instrument.add(\numJabs -> Array.fill(3, 0.0));

			OSCdef(interface ++ "/jabMap", {
				arg msg;
				var jabNote = msg[1], note=1;
				("jab" + jabNote).postln;

				instrument[\numJabs] = instrument[\numJabs].shift(1).putFirst(jabNote);
				instrument[\numJabs].postln;

				instrument[\notes] = instrument[\notesConstruct].value(instrument[\chords].wchoose(instrument[\chordsWeight]));
			}, interface ++ "/instrument/jabxyz", recvPort: port);


			////////////////////////////////
			// test triple tap
			instrument.add(\numTap -> 0);

			OSCdef(interface ++ "/ttapMap", {
				arg msg;
				var tap = msg[1], note=0;
				("ttap" + tap).postln;
				instrument[\numTap] = instrument[\numTap] + tap;
				note = instrument[\numTap]%2;
				note.postln;

				instrument[\notes] = Array.fill(instrument[\notes].size, instrument[\root][0])
			}, interface ++ "/instrument/button/ttap", recvPort: port);


			// FSR and shakeX Calibration
			OSCdef(instrument[\interface] ++ "/calibration", {
				arg msg;
				var tog;

				instrument[\toggle] = (instrument[\toggle] + 1)%8;

				case
				{ instrument[\toggle] == 1 } {
					instrument[\mappingGrp].free; // frees mapping nodes -> cuts off sound
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/raw/fsr"], instrument[\calibrationVals], \fsr);
					"FSR Calibration Started".postln;

				}
				{ instrument[\toggle] == 3 } {
					instrument[\calibrationFunc].(0);
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"].subBus(0), instrument[\calibrationVals], \shakeThresh);
					"FSR Calibration Completed".postln;
					"Shake Threshold Calibration Started".postln;

				}
				{ instrument[\toggle] == 5 } {
					instrument[\calibrationFunc].(0);
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"].subBus(0), instrument[\calibrationVals], \shakeMax);
					"Shake Threshold Calibration Completed".postln;
					"Maximum Shake Calibration Started".postln;

				}
				{ instrument[\toggle] == 7 } {
					instrument[\calibrationFunc].(0);
					"Maximum Shake Calibration Completed".postln;
					instrument[\makeBusMappings].();
				}
			}, instrument[\interface] ++ "/instrument/button/tap", recvPort: port);

			//
			// ("disable OSCdef" ++ interface ++ "/batteryCheck").postln;
			// OSCdef((interface ++ "/batteryCheck").asSymbol).disable; // GOOD!
			// OSCdef((interface ++ \touch).asSymbol).disable;
			// OSCdef(interface ++ \accl).disable;
			// OSCdef(interface ++ \fsr).disable;
			// OSCdef(interface ++ \gyro).disable;
			// OSCdef((interface ++ \shake).asSymbol).disable;
			// OSCdef(interface ++ \jab).disable;
			// OSCdef(interface ++ \ttap).disable;
			// OSCdef(\testFM).disable;






			(interface + ": OSCdef created").postln;"--------------------------------".postln;
			// Last step of process: OSCdef creation
			(interface + ": DMI READY").postln;"--------------------------------".postln;"".postln;
		});
	});
	// end of \specificFunctions function

	////////////////////////////////
	//4. register functions with ServerBoot/Quit/Tree
	////////////////////////////////

	// declare a function for registering functions
	instrument.add(\functionsRegister -> {
		ServerBoot.add(instrument[\makeBuffers]);
		ServerBoot.add(instrument[\makeBusses]);
		// ServerBoot.add(instrument[\makeOSCdef]); // moved to \remaining functions
		(interface + ": Functions registered").postln;
	});
	// end of \functionsRegister function

	////////////////////////////////
	//5. boot server
	////////////////////////////////

	// waitForBoot executed in the main SC file

	////////////////////////////////
	//6a. SynthDefs
	////////////////////////////////

	// declare a function for adding SynthDefs to the server
	instrument.add(\synthDefServerAdd -> {

		// FM SynthDef
		~synthDefMaker.(\fmChowningLag_N, {
			arg out=0, c=220, cm=1, index=0, amp=0.4, atk=0.01, rel=1, atkCrv=0, relCrv=0, gate=1, lag=0.1, inIndex=0;
			var freq, sig, env, envI, carr, modI, pan;
			c = Lag.kr(c, lag);
			envI = EnvGen.kr(Env.perc(atk, rel, 4), gate)*0; // CHECK ENVINDEX
			modI = In.kr(inIndex, 1); // inIndex is the bus where the index modulation is read
			// index = Lag.kr(index, lag);
			index = Lag.kr(index, lag) * modI; // added modulation of index
			freq = (index + envI) * c / cm * SinOsc.ar(c / cm) + c;
			env = EnvGen.kr(Env.asr(atk, 1, rel, [atkCrv, relCrv]), gate, doneAction: 2) * amp;
			sig = SinOsc.ar(freq) * env;
			sig = LeakDC.ar(sig);
			pan = LFNoise2.ar(LFNoise1.kr(1).range(0.1, 1.0)).range(-0.8, 0.8);
			Out.ar(out, PanAz.ar(instrument[\audioChan], sig, pan)); // mono if \audioChan = 1
		});

		// Control SynthDef
		~synthDefMaker.(\modulatorCm, {
			arg in = 0, out = 0, dev = 1, cm = 1;
			var sig;
			sig = LFNoise2.kr(LFNoise1.kr(5).range(0.5, 2)).range(dev.reciprocal, dev) * cm;
			Out.kr(out, sig);
		});

		// Control SynthDef
		~synthDefMaker.(\modulatorIndex, {
			arg in = 0, out = 0, dev = 1;
			var sig;
			sig = LFNoise2.kr(LFNoise1.kr(5).range(0.05, 0.5)).range(dev, dev.reciprocal);
			Out.kr(out, sig);
		});


		// envelope generator using a Schmidt trigger
		~synthDefMaker.(\schmidtEnv, {
			arg in=0, out=0, lowT=0.15, highT=0.3, level=1.0, levTune=1.0, atk=0.01, release=1.0, relTune=1.0;
			var input, env, gate;
			input = In.kr(in, 1).abs;
			gate = Schmidt.kr(input, lowT, highT);
			env = EnvGen.kr(Env.asr(atk, levTune, relTune * release, 0), gate) * level + instrument.[\fmAmp];
			Out.kr(out, env);
		});

		// Effects
		// low-pass filter
		~synthDefMaker.(\lpf, {
			arg in=0, out=0, fFreq=5000, rq=1.0;
			var sig;
			fFreq = fFreq.lag(0.1);
			// fFreq.poll;
			sig = In.ar(in, 2); // MODIFY FOR MONO/STEREO???
			// sig.poll(label: "in");
			// sig = LPF.ar(sig, fFreq);
			sig = RLPF.ar(sig, fFreq, rq);

			ReplaceOut.ar(in, sig);
			// Out.ar(out, sig);
		});

		// // Stereo Chorus
		// // https://scsynth.org/t/chorus-effect-design/5512
		// // 3 tap chorus
		// It is ok to use instrument[\audioChan] for mono/stereo mode since the SynthDef is defined in the instrument
		~synthDefMaker.(\stereoChorus, {
			arg in=0, out=0, mix=0;
			var dry, wet, sig, nTap;
			nTap = 3;
			// define if audio coming in is mono or stereo
			dry = In.ar(in, instrument[\audioChan]);
			// wet calculation
			wet = instrument[\audioChan].collect{ |i|
				DelayC.ar(
					dry,
					0.03,
					SinOsc.ar(0.1, ((0..nTap - 1) + (i * 0.5)) / nTap * 2pi)
					.linlin(-1, 1, [10e-3, 5e-3][instrument[\audioChan] - 1], 20e-3)
				).sum / sqrt(nTap);
			};
			// 2 channel equal power crossfade (mix/pan in [-1,+1])
			sig = XFade2.ar(dry, wet, mix);
			ReplaceOut.ar(in, sig);
		});

		// reverb -> declared in main SC file

		// security compressor -> declared in main SC file


	});
	// end of \synthDefs function

	////////////////
	//6b. Register remaining functions
	////////////////

	// declare remaining functions
	instrument.add(\remainingFunctions -> {

		// Create FSR envelope in a buffer
		instrument[\fsrBuf].sendCollection(
			Env.new(
				[instrument[\fcMax], instrument[\fcMin], instrument[\fcMax]],
				[
					instrument[\calibrationVals][\fsr][1]*0.9 - instrument[\calibrationVals][\fsr][0],
					instrument[\calibrationVals][\fsr][1] - (instrument[\calibrationVals][\fsr][1]*0.9)
				],
				[0, -4]
			).discretize;
		);

		// Create audio Synth then wait for command to be completed
		ServerTree.add(instrument[\makeNodes]);
		s.sync;

		// Create mapping Synth then wait for command to be completed
		ServerTree.add(instrument[\makeBusMappings]);
		s.sync;

		// Maps Synth parameters to control busses
		ServerTree.add(instrument[\makeMaps]);
		s.sync;

		// Create OSCdef (make sure all busses and mapping synth are already created)
		ServerTree.add(instrument[\makeOSCdef]);

	});
	// end of \remainingFunctions


	////////////////////////////////
	// return the instrument dictionary
	////////////////////////////////
	instrument;
}
)






