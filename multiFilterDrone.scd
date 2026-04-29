// this instrument requires the installations of SC3 plugins: https://supercollider.github.io/sc3-plugins/
(
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
		instrument.add(\recvPort -> port);
		// default mode is stereo
		instrument.add(\audioChan -> (mode != "mono").if(2,1)); // NECESSARY???

		// project path
		instrument.add(\projectPath -> PathName.new(thisProcess.nowExecutingPath).parentPath);

		// List of DMI control parameters [OSC address, size, mapped or not]
		instrument.add(\tStickParam -> [
			["/raw/capsense"                 ,      30,         ], // dedicated OSCdef
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
			["/instrument/jabxyz"            ,       3,         ],
			["/instrument/brush"             ,       1, "mapped"],
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

		// Number of partials
		instrument.add(\numPartials -> 15);

		// timbre presets
		// [harmo, rq, ampMat, freqMuls..., amps..., timeScale...]
		instrument.add(\timbre -> Dictionary.newFrom([
			\p2nuage,
			[
				1.2, 0.001, 40.dbamp,
				Array.rand(instrument[\numPartials], 0.99, 1.01),
				Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			// \p4drone,
			// [
			// 	2.05, 0.050, 6.dbamp,
			// 	Array.rand(instrument[\numPartials], 0.99, 1.01),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.25).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			\p3rumble,
			[
				0.01, 0.200, 10.dbamp,
				// ([1] ++ Array.rand(instrument[\numPartials]-1, -3, 3).midiratio) * 1, // RETRAVILLER
				([4] ++ Array.rand(instrument[\numPartials]-1, -3, 3).midiratio) * 1, // RETRAVILLER
				Array.geom(instrument[\numPartials], 1.0, 0.95).normalizeSum,
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			\p1crackle, // formerly rumblebis
			[
				2.05, 0.050, -6.dbamp,
				[1] ++ Array.rand(instrument[\numPartials]-1, -3, 3).midiratio,
				Array.geom(instrument[\numPartials], 1.0, 0.95).normalizeSum,
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			// \rumble3,
			// [
			// 	2.05, 0.050, 34.dbamp,
			// 	[1] ++ Array.rand(instrument[\numPartials]-1, -12, 12).midiratio,
			// 	Array.fill(instrument[\numPartials], 1).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			// \woodPerc,
			// [
			// 1.2, 0.01, 60.dbamp,
			// 	Array.fill(instrument[\numPartials], 1.0),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.25)
			// ].flat,
			// \p4stonePerc,
			// [
			// 	0.001, 0.01, 20.dbamp,
			// 	Array.fill(instrument[\numPartials], 1.0),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.25),
			// ].flat
		]);
		);

		// Sorted timbre names
		instrument.add(\sortedTimbre -> instrument[\timbre].keys.asArray.sort);

		// Calculation of each timbre preset highest partial
		// will be used for filtering
		instrument.add(\timbreHiPartials -> instrument[\sortedTimbre].collect{
			|name, i|
			// calculate all partials
			(
				Array.series(
					instrument[\numPartials],
					1,
					instrument[\timbre][name][0]
				) * instrument[\timbre][name].copyRange(3, 2 + instrument[\numPartials])
			).maxItem;
		});

		// List of sound synthesis control parameters [, [intial values], mapped or not]
		instrument.add(\synthParam -> [
			["freq"          ,                                                          [ 220 ],         ],
			["harmo"         ,                                                            [ 1 ], "mapped"],
			["freqMuls"      ,                          Array.fill(instrument[\numPartials], 1),         ],
			["envSel"        ,                                                            [ 0 ],         ],   // SUPPRIMÉ???
			["ampMat"        ,                                                          [ 1.0 ], "mapped"],   // REMPLACÉ PAR PRESET
			["amps"          , Array.fill(instrument[\numPartials], 1/instrument[\numPartials]),         ],
			["amp"           ,                                              Array.fill(6, 0.4), "mapped"],  // each key can have a different loudness
			["pos"           ,                                                          [ 0.7 ],         ],
			["rq"            ,                                                          [ 0.1 ],         ],
			["gate"          ,                                    [ 1 ],         ],
			["timeScale"     ,                                    [ 1 ],         ],
			["atk"           ,                                  [ 0.1 ],         ],
			["rels"          ,                         Array.fill(6, 1), "mapped"],
			["revMix"        ,                                 [ 0.33 ], "mapped"],
			["revRoom"       ,                                  [ 0.5 ], "mapped"],
			["revDamp"       ,                                  [ 0.2 ], "mapped"],
			["gainLow"       ,                                    [ 1 ], "mapped"],
			["gainMid"       ,                                    [ 1 ], "mapped"],
			["gainHigh"      ,                                    [ 1 ], "mapped"],
			["descriptors"   ,                         Array.fill(5, 0),         ],
			["timbre"        ,           instrument[\timbre].asArray[0], "mapped"],
			["partialsAmod"  ,                          Array.fill(instrument[\numPartials], 1), "mapped"],
			["partialsFmod"  ,                          Array.fill(instrument[\numPartials], 1), "mapped"],
			["hiPartialsMod" ,                  Array.fill(6, instrument[\timbreHiPartials][0]), "mapped"],
			["rqMod"         ,                                    [ 1 ], "mapped"],
			["presetSel"     ,                                    [ 0 ], "mapped"], // Bus for timbre preset selection
			["dustDens"      ,                                [ 50000 ], "mapped"],
			["dustAmp"       ,                              [ 0.dbamp ], "mapped"], // USED???
			["vibratoStrips" ,                         Array.fill(7, 0), "mapped"],
			["vibrato"       ,                         Array.fill(6, 1), "mapped"],
			// ["loudness"       ,                         [0, 0], "mapped"],
		]);


		// 6 notes: 1 octave of minor penta scale
		instrument.add(\minorPenta -> (55 * [1, 6/5, 4/3, 3/2, 7/4, 2]));

		// note state: noteOn/noteOff
		instrument.add(\noteState -> Array.fill(6, 0));
		// noteAmp window (store last 10 values ~ 10 * 8 ms)
		instrument.add(\noteAmpW -> Array.fill(6, Array.fill(10, 0)));

		// control area state
		instrument.add(\ctrlState -> 0);

		// octave control parameter (increments calculated in OSCdef)
		instrument.add(\synthOct -> 0);

		// Synth management
		instrument.add(\synthIndex -> 0); // incremental index of audio synth
		instrument.add(\numGrp -> 3); // number of groups to store audio Synth
		instrument.add(\synthGrpSize -> 32); // number of audio Synth per group
		instrument.add(\prevGrp -> 1); // because first Synth are sent to group 0, (0 - 2).wrap(0, 2) = 1

		// Minimum and maximum touch sensor values
		instrument.add(\touchMin -> Array.fill(30, 1e12 ));
		instrument.add(\touchMax -> Array.fill(30, -1e12 ));
		// Assume a minimum value of 75 to cover for ghost triggers
		// instrument[\touchMin] = Array.fill(30, 50);
		instrument[\touchMin] = [150, 150, 150, 150, 150, 150, 150, 150, 150, 150, 150, 150, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50];
		instrument[\touchMax] = [801.6, 1355.8, 1297.4, 1002, 698, 596, 654, 655, 667.4, 745, 781, 799, 771, 799.6, 717.6, 806, 847, 849, 890, 926, 977, 750.8, 670, 991, 991, 1029, 1009, 1047, 1463.8, 1380.4];

		// threshold of note area for triggering (trill should be scaled above 0.1 see normalization)
		instrument.add(\noteThresh -> 0.0);

		// Turn on/off calibration
		instrument.add(\toggle -> 0);

		// Dictionnary containing calibration results
		instrument.add(\calibrationVals -> Dictionary.with(*[
			\fsr -> [690, 2800],
			\shakeThresh -> [0, 2.5],
			\shakeMax -> [0, 5]
		]));
		//

		// Dictionary of SynthDef arguments
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

		// function returns an array of objects assigned to a key in an array of Dictionaries
		instrument.add(\arrayKey -> {
			arg list, key;
			list.collect({
				arg item, i;
				item[key];
			});
		});

		// create speciific functions

		// Buffers creation
		instrument.add(\makeBuffers -> {
			// Create a buffer to store timbre presets - from presets names in alphabetical order
			instrument.add(\bufPreset ->
				Buffer.loadCollection(s,
					(instrument[\sortedTimbre].collect{|i| instrument[\timbre][i]}).flat
				)
			);
			"".postln;"--------------------------------".postln; (interface + ": Buffers created").postln;"--------------------------------".postln;
		});

		// note loudness compensation
		instrument.add(\noteComp -> {
			|freq, ref=440, slope = -4, maxBoost = 12, maxCut = -6|
			var db;

			// log2-based tilt (musically natural)
			db = slope * (freq / ref).log2;

			// clamp to avoid extremes
			db = db.clip(maxCut, maxBoost);

			db.dbamp; // convert dB → linear gain
		});

		// descriptor calculation function
		instrument.add(\acssk -> {
			arg array = [];
			var area=nil, centroid=nil, spread=nil, skewness=nil, kurtosis=nil;

			// Include a condition to avoid division by zero
			if(array.sum > 0, {
				// area calculation (input array must be scaled appropriately to return a normalized area value between 0 and 1)
				area = array.sum; //
				// normalized centroid calculation
				centroid = (array / array.sum * Array.series(array.size) / (array.size - 1)).sum;
				// spread
				spread = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).squared ).sum ).sqrt;
				(spread == 0.0 ).if(
					// skewness & kurtosis
					{
						skewness = 0;
						kurtosis = 0;
					},{
						skewness = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).cubed ).sum ) / spread.cubed;
						kurtosis = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).pow(4) ).sum ) / spread.pow(4) ;
					}
				);
			},{
				// nil
				area = 0; centroid = 0; spread = 0; skewness = 0; kurtosis = 0;
			});
			array = [area, centroid, spread, skewness, kurtosis];
		});

		// Calibration Function
		instrument.add(\calibrationFunc -> {
			arg onOff=0, bus=0, dict=nil, key=nil;
			var arr=[], val, minVal=4095, maxVal=0;

			if(onOff == 1) {
				instrument.add(\calibRoutine -> Routine{
					loop{
						val = bus.getnSynchronous;
						val = val.mean;

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

		// Create control busses when server has booted
		instrument.add(\makeBusses -> {
			var bus = 0;
			// Dictionary of busses, keys are DMI source names
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

			// // ADDITIONAL BUS CREATED NECESSARY???
			// instrument[\busDmi].add((interface ++ "/capsDiff") -> Bus.control(s, 15));

			// Dictionary of busses, keys are Synth arguments names
			// CONTROL busses
			bus = 0;
			instrument.add(\busSynth -> Dictionary.new);
			instrument[\arrayKey].value(instrument[\synthDefParam], \arg).do({
				arg item, i;

				// bus number of channels is the size of the parameter initial value
				instrument[\busSynth].add(item -> Bus.control(s, instrument[\synthDefParam][i][\init].size));
				instrument[\busSynth][item].setn(instrument[\synthDefParam][i][\init]);
				// increment total number of control busses
				bus = bus + instrument[\synthDefParam][i][\init].size;
			});
			// additional AUDIO busses for fx (reverb etc) and limiter
			instrument[\busSynth].add(\fx -> Bus.audio(s,instrument[\audioChan]));
			instrument[\busSynth].add(\lim -> Bus.audio(s,instrument[\audioChan]));
			(interface  ++" Synth control busses: "++ bus.asString).postln;
		});

		// Cretate Synth mapping the interface control busses to sound parameters control busses
		instrument.add(\makeBusMappings -> {
			s.bind({
				instrument.add(\mappingGrp -> Group.new);
				// {
				// 	// mapping for Synth parameter dustDens & dustAmp (amp correction)
				// 	//
				// 	var fsr, dens, dustAmp;
				// 	fsr = In.kr(instrument[\busDmi][interface ++ "/raw/fsr"], 1);
				// 	// map FSR values to dust density
				// 	// dens = fsr.lincurve(0, 3000, 20000, 5, -10);
				// 	dens = fsr.lincurve(1000, 4000, 5, 20000, 4);
				// 	// map density to an amplitude correction
				// 	dustAmp = dens.lincurve(5, 20000, 30.dbamp, -10.dbamp);
				// 	// dens.poll;
				// 	Out.kr(instrument[\busSynth]["dustDens"], dens);
				// 	Out.kr(instrument[\busSynth]["dustAmp"], dustAmp);
				// }.play(instrument[\mappingGrp]);

				{
					// mapping for rq modulation
					//
					var fsr, rq, rqMod;
					fsr = In.kr(instrument[\busDmi][interface ++ "/raw/fsr"], 1);
					rq = In.kr(instrument[\busSynth]["timbre"].subBus(1), 1);

					// map FSR values to rq modulation coefficient
					rqMod = fsr.lincurve(instrument[\calibrationVals][\fsr][0] * 1.2, instrument[\calibrationVals][\fsr][1], 1, 10, -2, \min) * rq;

					// REQUIRES AMPLITUDE LIMITATION???

					Out.kr(instrument[\busSynth]["rqMod"], rqMod);
				}.play(instrument[\mappingGrp]);

				{
					// REVIST BOF map to shake???
					// mapping for partials modulation
					//
					var aMod, fMod, shake, shakeMean, aDev, fDev, speed, aPartials, fPartials, numPartials = instrument[\numPartials], oct;
					shake = In.kr(instrument[\busDmi][interface ++ "/instrument/shakexyz"], 3).mean;

					// read fMuls on timbre control bus
					fPartials = In.kr(instrument[\busSynth]["timbre"].subBus(3, numPartials), numPartials);
					// read amps on timbre control bus
					// aPartials = In.kr(instrument[\busSynth]["timbre"].subBus(numPartials + 3, numPartials), numPartials);

					// Running average over 60 control cycles
					// OSC messages received at about 125 Hz
					// Control block size: 64 samples -> 750 Hz (SR = 48 kHz)
					// 60 cycles ~ 10 OSC values
					shakeMean = RunningSum.kr(shake, 60) * (60.reciprocal);
					// shakeMean.round(0.1).poll(label: "shake");

					// aDev = (shake.mean.linlin(-5, 5, -10, 10, nil)).dbamp;
					// Partial frequency deviation (for ref FM patch, max dev 3)
					// fDev = (shakeMean.lincurve(instrument[\calibrationVals][\shakeThresh][1] * 0.8, instrument[\calibrationVals][\shakeMax][1], 1, 12.midiratio * 2.pow(2 - instrument[\synthOct]), -4, \min));
					fDev = (shakeMean.lincurve(instrument[\calibrationVals][\shakeThresh][1] * 0.8, instrument[\calibrationVals][\shakeMax][1], 1, 12.midiratio, -4, \minmax));
					fDev = LagUD.kr(fDev, 0.5, 2.0);
					// fDev.poll;
					// fDev.round(0.1).poll(label: "dev");
					// partials amp modulation
					// aMod = LFNoise2.kr(speed.dup(numPartials)).range(aDev, aDev.reciprocal) * aPartials;

					// partials freq modulation
					// fMod = LFNoise0.kr(LFNoise1.kr(5).range(0.5, 2).dup(numPartials)).range(fDev, fDev.reciprocal) * fPartials;
					fMod = LFNoise2.kr(LFNoise1.kr(5).range(0.5, 2).dup(numPartials)).range(fDev, fDev.reciprocal) * fPartials;

					// Out.kr(instrument[\busSynth]["partialsAmod"], aMod);
					Out.kr(instrument[\busSynth]["partialsFmod"], fMod);
				}.play(instrument[\mappingGrp]);



				// Mapping for timbre parameters
				{
					//
					var gyro, switchPos, switchNeg, locking, latch;
					var thresh = [[4, 3, 3], [5, 4, 4]], ceiling = [10, 6, 8];
					var trig, selector = 0;
					var preset, base = 0, numParams, params = instrument[\timbre][\p1bell];
					// var lag = Array.fill(48, {1.0.rrand(2.0)});
					var lag, curv;

					// FLICK VERSION
					// gyroX values are read from control busses
					// selector is calculated to read the preset buffer \bufPreset

					// // 1st step is to read gyro values around x-axis
					gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"].index, 1);

					// temporary switch (Schmidt trigger)
					// PAS SÛR DE GARDER le trigger temporaire
					// +1
					// lag to slow back down???
					switchPos = Schmidt.kr(gyro, 5, 10);
					// switchPos = Schmidt.kr(gyro, 4, 5).poll(label: "switchPos");
					// +1 when neg
					switchNeg = Schmidt.kr(gyro.neg, -5.neg, -10.neg);
					// switchNeg = Schmidt.kr(gyro.neg, -4.neg, -5.neg).poll(label: "switchNeg");

					// trigger counter update
					// PulseCount.kr(HPZ1.kr(switchPos) > 0).poll(label: "went up");
					// PulseCount.kr(HPZ1.kr(switchNeg) > 0).poll(label: "went down");

					// calculate selector (timbre preset number)
					selector = (
						PulseCount.kr(HPZ1.kr(switchPos) > 0) - PulseCount.kr(HPZ1.kr(switchNeg) > 0)
					);
					selector = (selector + 1) % 3;
					// selector.poll;

					// check if the preset selector changed value
					// Impulse.kr(0) plays a single impulse as initial trigger
					trig = Changed.kr(selector) + Impulse.kr(0);
					numParams = instrument[\busSynth]["timbre"].numChannels;
					lag = Array.fill(numParams, {0.5.rrand(2.0)});
					curv = [-4.0] ++ Array.fill(numParams - 1, {-4.0.rrand(4.0)});
					// lag.poll(label:"lag");
					// lag = LFNoise1.kr(0.5!numParams).range(0.5, 2.0);
					// lag.poll;
					// position to read from in the buffer
					// reminder: timbre presets are loaded in alphabetical order in the buffer
					base = selector * numParams;
					// base.poll;

					// Latch to the new values, with a lag COMMENT MAPPER LA VALEUR DE LAG
					params = VarLag.kr(
						Array.fill(
							numParams, {
								arg i;
								Latch.kr(
									BufRd.kr(1, instrument[\bufPreset], base + i),
									trig
								)
						}), lag,
						curvature: curv,
						// warp: \sin
					);
					Out.kr(instrument[\busSynth]["timbre"], params);

					// also write the preset number on its control bus
					Out.kr(instrument[\busSynth]["presetSel"], selector);

				}.play(instrument[\mappingGrp]);

				//
				// Mapping of gyro to mid-shelf filter frequencies
				//
				instrument.add(\gyroToMidShelf -> {
					var hiPartialRatio = instrument[\timbreHiPartials][0];
					var gyro, preset, mvt, dev, mod;
					gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"].index, 3);
					preset = In.kr(instrument[\busSynth]["presetSel"].index, 1);



					// quantity of movement as average of abs values
					gyro = Median.kr(2001, gyro);
					mvt = gyro.abs.mean;
					// use a lpf to smooth (0.5s period averaging) IF NECESSARY
					// use Median.kr ?
					// mvt = Median.kr(99, mvt);

					// 1 TESTER AS-IS
					// 2 AJOUTER Median.kr SI NÉCESSAIRE
					// 3 OBSERVER SCOPE

					// calculation of the deviation
					dev = 4 * mvt + 1;
					// dev.poll(label: "dev");

					// there can be up to 6 synth playing simultaneously
					//
					// là je peux écrire des valeurs de modulation

					// je dois réfléchir à QUOI moduler
					// moduler hiFreq (moduler loFreq revient au même)

					// quand le synth se déclenche, hiFreq est mappé sur le bus du même indice
					// la valeur de hiFreq dépend du preset de timbre
					// est-ce possible de calculer hiFreq à partir du dictionnaire \timbre

					// Select highest paretial ratio corresponding to selected timbre preset
					hiPartialRatio = Select.kr(preset, instrument[\timbreHiPartials]);

					//
					// INITIALZE SYNTH AT 0.8 * HIPARTIAL
					// MODULATE UP TO 1.2 * HIPARTIAL
					// Down to Max(1.5, 0.4*hiPartial)
					// use fold

					// the synth will modulate the ratios of fundamental frequency and highest partial (arguments )
					// mod is Array(6)
					// 1.5 factor to make sure highest partial not attenuated (headroom)
					// highest partial can only be attenuated

					// utiliser .fold(lo, hi)
					// folding higher frequency for LPF
					// make sure it does not filter below 1.5 fundamental frequency
					// .fold(( 0.4 * hiPartialratio).max(1.5), 1.2 * hiPartialRatio)
					// folding lower frequency for HPF
					// .fold(0.7, )

					// modulation value centered around 0.8 * hiPartialRatio
					mod = (
						(0.8 * hiPartialRatio) * LFNoise2.kr(LFNoise1.kr(5.dup(6)).range(0.05, 0.5)).range(
							dev.reciprocal, 1
						)
					);
					// ).fold(1.5, 1.5 * hiPartialRatio);
					// mod.poll(label: "mod");

					// Add combination with inclination (accX) for
					// écrire les valeurs de modulation sur des bus dédiés à loFreq et hiFreq pour chaque note possible (params de synthèse)

					Out.kr(instrument[\busSynth]["hiPartialsMod"], mod);
				}.play(instrument[\mappingGrp]);
				); //

				//
				// Mapping of gyro to reverb Synth parameters revMix, revRoom, revDamp
				//
				{
					var mapRevMix, mapRevRoom, mapRevDamp, gyro;
					gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"].index, 3);
					//
					mapRevMix = (gyro[0].abs + gyro[1].abs + gyro[2].abs).lincurve(0, 1.0, 0.1, 0.6, -5.4, nil);
					mapRevRoom = ((gyro[0].abs + gyro[1].abs + gyro[2].abs) / 3).lincurve(0, 1.0, 0.2, 0.8);
					// mapRevRoom.poll;
					mapRevDamp = ((gyro[0].abs + gyro[1].abs + gyro[2].abs) / 4).clip(0.0, 1.0);
					// Write on control busses
					Out.kr(instrument[\busSynth]["revMix"], mapRevMix);
					Out.kr(instrument[\busSynth]["revRoom"], mapRevRoom);
					Out.kr(instrument[\busSynth]["revDamp"], mapRevDamp);
				}.play(instrument[\mappingGrp]);

				// // Loudness and true-peak REMOVE
				// instrument.add(\loudness -> {
				// 	// arg test = -12.dbamp;
				// 	// var thresh = -12.dbamp;
				// 	var audio = In.ar(instrument[\busSynth][\fx], 1);
				// 	var loudness, comp;
				// 	// thresh = test;
				// 	// comp = CompanderD.ar(audio, -12.dbamp, 1.0, 4, 0.01, 0.01);
				// 	comp = CompanderD.ar(audio, -36.dbamp, 1.0, 1/3, 0.01, 0.01).poll;
				// 	loudness = FluidLoudness.kr(comp);
				// 	loudness[0].poll(label:"Loudness:");
				// 	loudness[1].poll(label:"TruePeak:");
				// 	Out.kr(instrument[\busSynth]["loudness"], loudness);
				// 	0.poll(label:"---------------------");
				// 	}.play(instrument[\fxGrp]);
				// );
			})
		});

		// Create audio Synth
		instrument.add(\makeNodes -> {
			s.bind({
				instrument.add(\mainGrp -> Group.new);
				// groups inside of main one for audio synth management
				instrument.add(\synthGrp -> Array.fill(instrument[\numGrp], {Group.new(instrument[\mainGrp])}));
				instrument.add(\fxGrp -> Group.after(instrument[\mainGrp]));
				instrument.add(\limGrp -> Group.after(instrument[\fxGrp]));

				// equalizer Synth
				// instrument.add(\eqSynth -> Synth(\equalization, [\in, out, \out, out, \ampMod, 0.25], instrument[\fxGrp]));
				// ~eqSynth = Synth(\equalization, [\in, 1, \out, 1, \ampMod, 0.25], ~fxGrp);


				// reverb Synth (tail of the fx group)
				instrument.add(\revSynth -> Synth.tail(instrument[\fxGrp], [\reverbMono, \reverbStereo][instrument[\audioChan] - 1], [
					\in, instrument[\busSynth][\fx],
					\mix, 0.33,
					\room, 0.5,
					\damp, 0.2,
				], instrument[\fxGrp]));

				// // Mid-Shelf Filter
				// instrument.add(\midShelfEQ ->
				// 	{
				// 		arg loGyro = 3, hiGyro = 12;
				// 		// audio in
				// 		var in = In.ar(instrument[\busSynth][\fx], instrument[\audioChan]);
				// 		// control busses
				// 		var gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"], 3);
				// 		var accX = In.kr(instrument[\busDmi][interface ++ "/raw/accl"], 1);
				//
				// 		var speed, pitchCrv, loFreq = 20, hiFreq = 20000;
				// 		var sig;
				//
				// 		// Mappingf for Mid-Shelf Filter
				// 		// modulation speed
				// 		speed = gyro.abs.mean;
				// 		// speed.poll;
				//
				// 		// sort of pitch angle from X acceleration
				// 		pitchCrv = accX.linlin(-10, 10, -4, 4);
				//
				// 		// when little movement, gyro ~0 -> speed ~0 -> very slow LFO and cutoff stays close to 20 Hz
				// 		// loFreq varies closer to 20 Hz when T-Stick is tipped down
				// 		loFreq = LFNoise2.kr( speed / 4 ).lincurve(
				// 			-1.0, 1.0,
				// 			20, speed.linlin(loGyro, hiGyro, 20, 500),
				// 		pitchCrv, \min);
				//
				// 		// maybe there is a way to make sure there is at least
				// 		hiFreq = LFNoise2.kr( speed / 4 ).lincurve(
				// 			-1.0, 1.0,
				// 			speed.linlin(loGyro, hiGyro, 20, 1000), 20000,
				// 		pitchCrv, \min);
				// 		// [loFreq, hiFreq].poll;
				// 		//
				// 		sig = LPF.ar(HPF.ar(in, loFreq), hiFreq);
				// 		ReplaceOut.ar(instrument[\busSynth][\fx], sig);
				// 	}.play(instrument[\fxGrp]);
				// );

				// limiter Synth
				// instrument.add(\limitSynth -> Synth(\comp, [\in, instrument[\busSynth][\fx], \thesh, -3.dbamp, \out, out], instrument[\limGrp]));
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

				// mappings


				// mappings of \triBand


				// mappings of \reverb
				instrument[\revSynth].map(\mix, instrument[\busSynth]["revMix"]);
				instrument[\revSynth].map(\room, instrument[\busSynth]["revRoom"]);
				instrument[\revSynth].map(\damp, instrument[\busSynth]["revDamp"]);
			});
		});

		////////////////////////////////
		// OSC message reception
		////////////////////////////////

		// FAIRE UN DICTIONNAIRE POUR ASSOCIER UN PARAM À UN BUS
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
			OSCdef(instrument[\interface] ++ "/batteryCheck", {
				arg msg;
				// (~tStick ++ " Battery: " ++ (msg[1]/100)).postln;
				defer{instrument[\slider].value_([msg[1]/100])};
			},instrument[\interface] ++ instrument[\batteryOSC], recvPort: instrument[\recvPort]);

			// Assign OSC data to control busses
			instrument[\busDmi].keys.do({
				arg item, i;
				// ~busDmi[item].postln;
				OSCdef(item, {
					arg msg;
					var val;
					// Remove the addres from the OSC message
					val = msg[1..];
					// make sure msg is an array the same size of control bus channel number (necessary?)
					val = val.reshape(instrument[\busDmi][item].numChannels);
					// (item + val).postln;
					instrument[\busDmi][item].setn(val);
				}, item, recvPort: instrument[\recvPort]);
			});

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
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"], instrument[\calibrationVals], \shakeThresh);
					"FSR Calibration Completed".postln;
					"Shake Threshold Calibration Started".postln;

				}
				{ instrument[\toggle] == 5 } {
					instrument[\calibrationFunc].(0);
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"], instrument[\calibrationVals], \shakeMax);
					"Shake Threshold Calibration Completed".postln;
					"Maximum Shake Calibration Started".postln;

				}
				{ instrument[\toggle] == 7 } {
					instrument[\calibrationFunc].(0);
					"Maximum Shake Calibration Completed".postln;
					instrument[\makeBusMappings].();
				}
			}, instrument[\interface] ++ "/instrument/button/tap", recvPort: instrument[\recvPort]);

			// REVISER!!!!!!!
			////////////////////////////////
			// TOUCH SENSOR OSCdef
			////////////////////////////////

			// difference of capsense values over a 10 messages window
			// WHY HOW DOES IT WORK???
			// function to calculate the difference between max and min values in an array
			instrument.add(\funDiff -> {arg array; array.maxItem - array.minItem;});
			// function to fill a row in a 2D array with an array of values
			instrument.add(\array2DrowPut -> {arg array2D, row, array; array.do{|val, i| array2D[row, i] = val} });

			// 2D array used to store 10 consecutive values for each of 15 pairs of touch sensor strips
			instrument.add(\capsBuf -> Array2D.fromArray(15, 10, 0.dup(150)));
			instrument.add(\capsDiff -> Array.fill(15, 0));

			instrument.add(\capsense -> Array.fill(15, 0)); // NECESSARY???? DUPLICATE FROM LLINE 50.... REMOVE!!!
			// arrays for 11 notes that can be played
			instrument.add(\synthTrig -> Array.fill(11, 0));
			instrument.add(\synthArray -> Array.fill(11, nil));

			// record if the touch sensor is armed for octave incrementing
			instrument.add(\octArmed -> true);

			// threshold for brush
			// instrument.add(\posBrush -> 0.15);
			// instrument.add(\negBrush -> -0.15);
			// instrument.add(\reArmBrush -> 0.0); // lower threshold for re-arming (when brush value decays back to 0)

			// record last time an octave brush was trigged
			instrument.add(\lastOctTime -> 0);
			instrument.add(\debounceOct -> 0.25); // 250 ms debounce

			// OSCdef reads raw touch sensor values
			OSCdef.new(interface ++ "/touchTrig", {
				arg msg;
				var touchVals, normTouch, noteVal = [], noteTrig = [], noteVib, ctrlArea;
				var acssk, ctrlOn, noteOn, ctrlOff, noteOff;
				var dustDens, dustAmp = 1.0, noteDB, noteAmp;
				var presetSel, params;
				var octCtrl, acclX, capsAtk, capsRel, amps, rqMod;
				var now = SystemClock.seconds; // current time
				// variables for synth management
				var targetGrpIndex, id;

				touchVals = msg[1..30];
				// normalizing touch sensor values (make sure normalized values don't go below 0)
				normTouch = touchVals.linlin(instrument[\touchMin], instrument[\touchMax], 0, 1, \min);

				// keep first 3 strips values for octave control (combined with brush)
				octCtrl = normTouch[0..2];

				// create an array for note values (average of 2 consecutive strip values)
				[29, 28, 26, 25, 23, 22, 20, 19, 17, 16, 14, 13].pairsDo{|a, b|
					noteVal = noteVal.add((normTouch[a] + normTouch[b]) / 2);
				};

				// every third strip from number 12 is reserved for vibrato
				noteVib = normTouch[(12, 15..27).reverse];
				// noteVib.round(0.1).postln;
				// write the values on a control bus
				instrument[\busSynth]["vibratoStrips"].setn(noteVib);

				// define control area
				ctrlArea = normTouch[4..11];
				// calculate descriptors for the control area
				// divide by number of strips to have A < 1
				acssk = instrument[\acssk].(ctrlArea / ctrlArea.size);

				// acssk.round(0.01).postln;
				// noteVal.round(0.01).postln;
				// normTouch.round(0.1).postln;

				// OCTAVE CALCULATION
				// check if a significant area of strips 0 to 2 are touched
				// returns 0 if all values are above 0.05, 1 otherwise
				//

				// get acceleration X value
				acclX = instrument[\busDmi][interface ++ "/raw/accl"].subBus(0).getSynchronous();

				// recalculate direction of octave increment
				// X acceleration outside of specified range, then octave will be incremented
				// acclX < 0 (button pointing down) -> octave up

				// acclX = (acclX.abs > 5).asInteger * acclX.sign.neg;
				acclX = (acclX.inclusivelyBetween(2, 6)).not.asInteger * acclX.sign;

				// octave calculation logic
				// touch sensor must be armed for octave increment

				if ( (instrument[\octArmed] == true).and( (now - instrument[\lastOctTime]) > instrument[\debounceOct]).and(octCtrl.sum > 0.7) ) {
					// evaluate octave

					// instrument[\synthOct] = (instrument[\synthOct] + acclX).clip(-1, 1);
					instrument[\synthOct] = (instrument[\synthOct] + acclX).clip(0, 2); // can only go up, max 2 octaves
					// octave control must be re-armed
					instrument[\octArmed] = false;
					// update last brush time
					instrument[\lastOctTime] = now;
					("octave " ++ instrument[\synthOct]).postln
				};
				// re-arm
				if ( (instrument[\octArmed].not) && (octCtrl.sum < 0.1) ) {
					instrument[\octArmed] = true;
				};


				// AMPLITUDE CALCULATION
				// calculate dust density from area of control surface
				// A = 0 -> impulses
				// A = 1 -> white noise
				// dustDens = acssk[0].lincurve(0.1, 0.5, 5, 12000, 8, \minmax); // RETRAVAILLER
				// split scaling at 30% area
				dustDens = if(acssk[0] < 0.4) {
					acssk[0].lincurve(0.1, 0.4, 2, 10, 1, \min);
				} {
					acssk[0].lincurve(0.4, 0.7, 10, 250, 2, \max);
				};
				// acssk[0].postln;
				// dustDens.postln;


				// write on a control bus (synth will be mapped to it for continuous control of density)
				instrument[\busSynth]["dustDens"].set(dustDens);

				// calculate dustAmp, amplitude correction (higher density equivalent to white noise gets too loud)
				// dustAmp = dustDens.lincurve(50, 10000, 40, 20, 0, \minmax).dbamp; // DÉSACTIVÉ POUR LE MOMENT
				// dustAmp = acssk[0].lincurve(0.1, 0.4, 40.dbamp, 20.dbamp, 0, \max);
				// split amp correction À REVISITER!!! REPLACED BY COMPRESSOR
				// dustAmp = if(acssk[0] < 0.4) {
				// 	acssk[0].lincurve(0.1, 0.4, 30, 10, 2, nil).dbamp;
				// } {
				// 	acssk[0].lincurve(0.4, 0.5, 10, 0, 4, \max).dbamp;
				// };

				// calculate notes amplitude
				// dustAmp included for loudness correction
				// noteAmp = noteVal.lincurve(0.0, 0.7, -60, 0, 0, \minmax).dbamp;
				noteAmp = noteVal.lincurve(0.0, 0.7, -60, 0, 0, \minmax).dbamp
				* instrument[\noteComp].(instrument[\minorPenta] * 2.pow(instrument[\synthOct])); // added note loudness compensation

				// noteAmp = noteDB * dustAmp;
				// [acssk[0], dustDens].postln;

				// noteAmp.ampdb.round(1.0).postln;
				//
				// ////////////////////////////
				// track acssk[0]
				// [acssk[0].round(0.01), dustDens.round(1.0), dustAmp.round(0.0001), noteDB[0].round(0.001), noteAmp[0].round(0.0001)].postln;
				// [acssk[0].round(0.01), dustDens.round(1.0), dustAmp.ampdb.round(0.1), noteDB[0].ampdb.round(0.1), noteAmp[0].ampdb.round(0.1)].postln;

				// write on a control bus (synth will be mapped to it for continuous control of amplitude)
				instrument[\busSynth]["amp"].setn(noteAmp);
				// instrument[\busSynth]["amp"].setn(Array.fill(6, 1.0)); // force Synth \amp

				// PRESET SELECTION
				// TEMPORARY - select preset based on centroid position IMPROVE!!!   // DÉSACTIVÉ -> preset sélectionné par FLICK
				// presetSel = (acssk[1] * 3).floor.clip(0, 2);

				// write preset value on control bus
				// only if area > 0 (prevent preset going back to 0 when fingers leave control area)
				// if(acssk[0] > 0) {instrument[\busSynth]["presetSel"].set(presetSel)}; // DÉSACTIVÉ

				// return timbre parameters
				// params = instrument[\timbre][[ \bell, \glass, \drone2, \nuage ][presetSel]];
				// instrument[\busSynth]["timbre"].setn(params);

				// Check if control area and some motes are both trigger ready
				// previous value
				// transient control state
				ctrlOn = (instrument[\ctrlState] == 0).and(acssk[0] > 0);

				ctrlOff = (instrument[\ctrlState] == 1).and(acssk[0] == 0);
				// instrument[\noteState].postln;
				// noteVal.round(0.01).postln;

				// transient note state MOVE into fi STATEMENT???
				noteOn = instrument[\noteState].collect{|item, i| (item == 0).and(noteVal[i] > instrument[\noteThresh])};
				noteOff = instrument[\noteState].collect{|item, i| (item == 1).and(noteVal[i] <= instrument[\noteThresh])};

				// [ctrlOn, ctrlOff, noteOn, noteOff].postln;

				// VIBRATO CALCULATION
				// noteVib write on HOW MANY busses?
				// CALCULATE TE PAIRS HERE OR IN THE SYNTH????



				// instrument[\noteState].postln;


				// NOTES TRIGGERING
				instrument[\synthArray] = noteVal.collect{
					arg item, i;
					var synth, freqDev;
					// check if ctrl area sustained and note on
					// or control area on and note sustained
					if(( (noteOn[i] == true).and(acssk[0] > 0) ).or( (noteVal[i] > instrument[\noteThresh]).and(ctrlOn == true) ), {
						(noteVal[i].round(0.01) + "trigged").postln;
						("octave " ++ instrument[\synthOct]).postln; // REMOVE!!!!

						// wrap synth ID allowed range
						id = instrument[\synthIndex] % (instrument[\numGrp] * instrument[\synthGrpSize]);

						// calculate target group index in the array
						targetGrpIndex = (id / instrument[\synthGrpSize]).floor;

						// detect group change (start new block of synth)
						if(targetGrpIndex !=  instrument[\prevGrp]) {
							// if synth is played in the next group, free all synth in group n-2
							instrument[\synthGrp][(targetGrpIndex - 2) % instrument[\numGrp]].freeAll;
						};

						// capsAtk[i].postln;
						freqDev = Array.fill(instrument[\numPartials], {-0.25.rrand(0.25).midiratio});
						synth = Synth(\multiFiltReson, [
							\freq, instrument[\minorPenta][i] * 2.pow(instrument[\synthOct]),
							// \freq, instrument[\minorPenta][i],

							// // bell sound
							\harmo, 1,
							\freqMuls, [1.0, 1.0, 0.844, 0.75, 0.826, 1.011, 1.228, 1.366, 1.504, 1.64, 1.782, 1.0, 1.0, 1.0, 1.0] * freqDev,
							\amps, [0.4, 1.0, 0.6, 0.4, 0.7, 0.6, 0.5, 0.1, 0.05, 0.01, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp].normalizeSum,
							\rq, 0.001,
							\ampMat, 30.dbamp,

							// \atk, capsAtk[i], // REWORK
							\atk, 0.001,
							// \decay, atk.lincurve(0.001, 0.5, 0.3, 0.001), // TBC!!!!
							\decay, 0.15,
							// \sus, 0.7/peak; // TBC!!!!!!!!
							\sus, 0.5,
							\amp, -10.dbamp,
							\out, instrument[\busSynth][\fx]
						],
						// select target group
						instrument[\synthGrp][targetGrpIndex]);

						// increment synth ID and group
						instrument[\synthIndex] = instrument[\synthIndex] + 1;
						instrument[\prevGrp] = targetGrpIndex;

						("Note: " ++ instrument[\minorPenta][i].round(0.1) ++ " Hz").postln;
						// ("Attack: " ++ capsAtk[i] ++ " s").postln;

						// map \amp to control busses
						synth.map(\amp, instrument[\busSynth]["amp"].subBus(i));

						// map \fDev to control bus
						// synth.map(\fDev, instrument[\busSynth]["vibrato"].subBus(i)); // UNMAP AT RELEASE???

						// map \dustDens to control bus
						synth.map(\dustDens, instrument[\busSynth]["dustDens"]);

						// map timbre parameters [harmo, rq, ampMat, freqMuls..., amps..., timeScale...] to control busses
						synth.map(\harmo,
							instrument[\busSynth]["timbre"].subBus(0)); // 1 channel
						synth.map(\rq,
							instrument[\busSynth]["rqMod"]); // 1 channel
						synth.map(\ampMat,
							instrument[\busSynth]["timbre"].subBus(2)); // 1 channel
						synth.map(\freqMuls,
							// instrument[\busSynth]["timbre"].subBus(3, instrument[\numPartials])); // n channels
							instrument[\busSynth]["partialsFmod"]); // n channels
						synth.map(\amps,
							instrument[\busSynth]["timbre"].subBus(instrument[\numPartials] + 3, instrument[\numPartials])); // n channels
						// instrument[\busSynth]["partialsAmod"], instrument[\numPartials]); // n channels
						synth.map(\timeScale,
							instrument[\busSynth]["timbre"].subBus(2 * instrument[\numPartials] + 3, instrument[\numPartials])); // n channels

						// map high partial modulation busses
						// synth.map(\hiPartialRatio, instrument[\busSynth]["hiPartialsMod"].subBus(i));
						// UNPLUGGED UNTIUL LOUDNESS CORRETION WORKS!!!
					}
					,{
						//
						synth = instrument[\synthArray][i];
					}
					);
					// release only if there is a synth
					// VÉRIFIER CE QUI FAIT LE noteOff
					// ([noteOn[0], noteOff[0]]).postln;
					if((noteOff[i] == true).or(ctrlOff == true).and(instrument[\synthArray][i].notNil), {
						// var relAmp = instrument[\busSynth]["amp"].subBus(i).getSynchronous();
						var relAmp;
						// noteOff[i].postln;
						// relAmp = ctrlOff.not.asInteger * noteAmp[i];
						// relAmp = ctrlOff.not.asInteger * instrument[\noteAmpW][i].maxItem; // max of 25 last values
						relAmp = ctrlOff.not.asInteger * instrument[\noteAmpW][i].mean; // mean of last 10 values
						instrument[\noteAmpW][i].mean.ampdb.round(1.0).postln;
						//
						// NEED TO MAINTAIN THE AMPLITUDE VALUE AFTER REMOVING FINGER -> UNMAP
						synth.set(\amp, relAmp);
						("amp value at release " ++ relAmp.ampdb.round(1.0) ++ " dB").postln;

						// update release times \rels
						// capsRel = instrument[\busSynth]["amp"].subBus(i).getSynchronous().lincurve(0, 1, 2, 6, 4);
						capsRel = noteVal[i].lincurve(0, 1, 2, 6, 4);
						("Release duration " ++ capsRel.round(0.01)).postln;
						synth.set(\rels, capsRel * Array.fill(instrument[\numPartials], {1.33.rrand(1.33.reciprocal)}));
						//

						// set timbre parameters to current values at release, so they remain fixed until Synth is freed
						// synth.set(\harmo, instrument[\busSynth]["timbre"].subBus(0).getSynchronous());
						// synth.set(\ampMat, instrument[\busSynth]["timbre"].subBus(2).getSynchronous());
						// synth.set(\freqMuls, instrument[\busSynth]["timbre"].subBus(2).getSynchronous());

						// need to freeze density as well (don't change texture during release)
						synth.set(\dustDens, dustDens);

						// release Synth envelope
						synth.set(\gate, 0);
						synth = nil;
					});
					synth;
				};


				// update state of control area
				instrument[\ctrlState] = acssk[0].roundUp(1.0).clip(0, 1);
				// update state of notes
				instrument[\noteState] = noteVal.roundUp(1.0).clip(0, 1);

				// update noteAmp values window
				instrument[\noteAmpW] = instrument[\noteAmpW].collect{|item, i| item.shift(1).putFirst(noteAmp[i])};
				// [noteVal.round(0.001), noteOn].postln;


			}, interface ++ "/raw/capsense", recvPort: port);





			(interface + ": OSCdef created").postln;"--------------------------------".postln;
			// Last step of process: OSCdef creation
			(interface + ": DMI READY").postln;"--------------------------------".postln;
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

		// Filter SynthDef
		~synthDefMaker.(\multiFiltReson, {
			arg out=0, freq=220, fDev=1.0, harmo=1.0, rq=0.1, atk=0.1, decay=0.1, sus=0.5, ampMat=1.0, envSel=0, amp=0.7, gate=1, pos=0.0, dustDens=5000, dustDev=0.5, fFundRatio = 0.5, hiPartialRatio = 50, loDev = 1, hiDev = 1, compTh = -18.dbamp, compR = 1/3;
			var envT, envN, env, sigMat, sigFilt, freqMax, peak, pan, sigComp;

			// envT = EnvGen.kr(Env.asr(atk, 1.0, \rels.kr( Array.fill(~numPartials, 1) )), gate); // plusieurs gates????
			// envN = EnvGen.kr(Env.perc(atk, \rels.kr( Array.fill(~numPartials, 1) )));
			// env = Select.kr(envSel, [envN, envT]);

			// cut higher frequencies (noisy) NECESSARY???
			freqMax = freq * ( (instrument[\numPartials]-1)*harmo +1);

			peak = atk.lincurve(0.001, 0.5, 1, 0.7); // AFFINER LES COEFFICIENTS
			// gate = 0 closes the envelop, but does not release Synth
			// Synth relase occurs later with Freeself and DetectSilence Ugens
			env = EnvGen.kr(Env.adsr(atk, decay, sus, \rels.kr( Array.fill(instrument[\numPartials], 10) ), 1.0), gate, timeScale: \timeScale.kr(Array.geom(instrument[\numPartials], 1.0, 1.0)));
			// env[0].poll;
			// sigMat = WhiteNoise.ar;
			// sigMat = Dust2.ar(dustDens);
			sigMat = GaussTrig.ar(dustDens, dustDev); // less random than dust, dev = 25% deviation (inspired by granulator)

			sigFilt = Mix.new(
				BPF.ar(
					sigMat,
					Array.series(
						// frequencies
						instrument[\numPartials],
						freq,
						freq * harmo
					) * \freqMuls.kr( Array.fill(instrument[\numPartials], 1)) * fDev,
					rq,
					\amps.kr( Array.fill(instrument[\numPartials], 1/instrument[\numPartials]) ) * ampMat
				) * env
			); //rq multiplié par amps (ou autre Array)

			sigFilt = LPF.ar(sigFilt, 0.5*freqMax);
			// sigFilt = BLowPass.ar(sigFilt, 0.5*freqMax, 0.3); // RETRAVAILLER!!!
			// sigFilt = BLowPass.ar(sigFilt, 0.5*freqMax, 2); // RETRAVAILLER!!!

			// LeakDC added for security TO BE TESTED
			// sigFilt = LeakDC.ar(sigFilt, 0.995);

			// Compressor Downward (classical)
			// sigComp = CompanderD.ar(sigFilt, -30.dbamp, 1.0, 1/4, 0.01, 0.01);
			// Compressor Upward
			sigComp = CompanderD.ar(sigFilt, -30.dbamp, 1/4, 1.0, 0.01, 0.01);

			// low cut frequency: freq * fFundRatio (fFundRatio should be initialized at 0.5)
			// sigFilt = HPF.ar(sigFilt, freq * fFundRatio);

			// high cut frequency: freq * hiPartial (hiPartial should be initialized at freqMax / freq * 3???)
			// sigFilt = LPF.ar(sigFilt, freq * hiPartialRatio);
			// sigComp = LPF.ar(sigComp, freq * LFNoise1.kr(0.5).range(0.5, 20)); // Aller surtout dans les basses....
			// (freq * hiPartialRatio).poll(label: "hiPartialRatio");

			// Panning
			pan = LFNoise2.ar(LFNoise1.kr(1).range(0.1, 1.0)).range(-0.3, 0.3) * (instrument[\audioChan] - 1);

			// sigFilt = PanAz.ar(); FINIR PUS TARD
			// Out.ar(out, PanAz.ar(2, sigFilt, pos, amp) ); // PanAz
			// amp is placed at the very end (after all processes)
			sigComp = sigComp * amp;
			// sigComp = sigFilt * amp;

			// Libérer le synth seulement quand toutes les enveloppes sont closes (quand le son est rendu très faible en fait)
			FreeSelf.kr(DetectSilence.ar(sigComp, -100.dbamp, time: 1.0)); // Freeself contrôlé par Mix(sig): 1 seul signal!

			Out.ar(out, PanAz.ar(instrument[\audioChan], sigComp, pan)); // Mono
			// Out.ar(out, sigComp); // Mono
		});

		// multiband equalizer TBC USAGE
		~synthDefMaker.(\equalization, {
			arg out=0, in=0, ampMod=0.25;
			var sig, dry;
			dry = In.ar(in, 1);
			sig = BPF.ar(
				dry,
				\freqs.kr(Array.series(10, 100, 1000)) * LFNoise2.kr(\modF.kr(Array.rand(10, 0.5, 2.0))).range(-3.dbamp, -3.dbamp),
				LFNoise2.kr(\modQ.kr(Array.rand(10, 0.5, 2.0))).range(0.1, 1.0)
			);
			sig = sig * LFNoise2.kr(\modA.kr(Array.rand(10, 0.5, 2.0))) * ampMod;
			sig = Mix.ar(sig);
			sig = dry + sig;
			Out.ar(out, sig);
		});

		// reverb -> declared in main SC file

	});
	// end of \synthDefs function

	////////////////
	//6b. Register remaining functions
	////////////////

	// declare remaining functions
	instrument.add(\remainingFunctions -> {

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

		// instrument[\timbreHiPartials].round(0.01).postln; // REMOVE
	});
	// end of \remainingFunctions


	////////////////////////////////
	// return the instrument dictionary
	////////////////////////////////
	instrument;
}
)
