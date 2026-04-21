(
// Check each instrument’s .scd file for plugins or Quarks that may require installation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                     START MAIN CODE                                                        //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////
// GUI definition
////////////////////////////////

// Choose if you want the GUI to be displayed to change server configuration
~displayGUI = false;
// ~displayGUI = false;

////////////////////////////////
// Start of the GUI function
////////////////////////////////
~mainGUI = {

	////////////////////////////////
	// 0. Orchestra variables and GUI
	////////////////////////////////

	// Initial Values for Server Configuration
	// var inDevice = "Windows WASAPI : Microphone Array (Realtek High Definition Audio)";
	var inDevice = "ASIO : ReaRoute ASIO (x64)";
	// var inDevice = "ASIO : AudioBox ASIO Driver";
	// var inDevice = "ASIO : ASIO MADIface USB";
	// var outDevice = "Windows WASAPI : Speaker/HP (Realtek High Definition Audio)";
	var outDevice = "ASIO : ReaRoute ASIO (x64)";
	// var outDevice = "ASIO : AudioBox ASIO Driver";
	// var outDevice = "ASIO : ASIO MADIface USB";
	var numInputBusChannels = 2;
	var numOutputBusChannels = 6; // MAKE SURE the nb of channels matches the configuration
	var sampleRate = 48000;

	// Instruments Definition
	var instruments = [
		["TStick_516", 8100, 0, "multiFilterDrone.scd", "stereo"],
		// ["TStick_514", 8000, 2, "fmSynth.scd", "mono"],
		// ["TStick_570", 8200, 4, "multiFilterLead.scd", "mono"],
	].collect{
		arg item, i;
		Dictionary.newFrom([\name, item[0], \port, item[1], \audioOut, item[2], \patch, item[3], \mode, item[4]]);
	};

	// Configuration window
	var wConfig;
	var wName = Array.newClear(instruments.size);
	var wPort = Array.newClear(instruments.size);
	var wOut = Array.newClear(instruments.size);
	var wPatch = Array.newClear(instruments.size);

	(~displayGUI).if(
		{
			// Create GUI elements if display is enabled
			"--------------------------------".postln;"      Initializing Patch".postln;"--------------------------------".postln;
			// main window
			wConfig = Window.new(
				"Server and instruments configuration",
				Rect(16, 800 - (64 * instruments.size + 128), 560, (42 * instruments.size + 48 + 128))
			);
			wConfig.view.background_(Color.new255(255, 255, 250));
			wConfig.view.decorator = FlowLayout(wConfig.view.bounds);
			wConfig.front.alwaysOnTop;

			// Server section
			StaticText(wConfig, 500@22).string_("Server Configuration").font_(Font("Bold", 14));
			// List all available input devices
			EZPopUpMenu.new(
				wConfig, 502@22, "Input Devices: ",
				// list items, assigns a new value to the input device when an item is selected
				ServerOptions.inDevices.collect({|device| device -> {inDevice = device}}),
				// checks if initial device is found in the list, then selects it in the menu, otherwise empty item is selected
				initVal: ServerOptions.inDevices.collect({|device| device }).collect({|item, i| (item == inDevice).if({i}, {-1})}).maxItem,
				initAction: true
			);
			// List all available output devices
			EZPopUpMenu.new(
				wConfig, 502@22, "Output Devices: ",
				// list items, assigns a new value to the output device when an item is selected
				ServerOptions.outDevices.collect({|device| device -> {outDevice = device}}),
				// checks if initial device is found in the list, then selects it in the menu, otherwise empty item is selected
				initVal: ServerOptions.outDevices.collect({|device| device }).collect({|item, i| (item == outDevice).if({i}, {-1})}).maxItem,
				initAction: true
			);
			// Sampple rate, number of inputs and output channels
			EZNumber(
				wConfig, 128@22, "Sample Rate: ", ControlSpec(1, 192000, \lin, 1, 48000),
				{|ez| sampleRate = ez.value.asInteger}, sampleRate, true
			);
			EZNumber(
				wConfig, 128@22, "Input Channels: ", ControlSpec(1, 256, \lin, 1),
				{|ez| numInputBusChannels = ez.value.asInteger}, numInputBusChannels, true
			);
			EZNumber(
				wConfig, 128@22, "Output Channels: ", ControlSpec(1, 256, \lin, 1),
				{|ez| numOutputBusChannels = ez.value.asInteger}, numOutputBusChannels, true
			);

			// Instruments
			StaticText(wConfig, 500@12);
			StaticText(wConfig, 500@16).string_("Instruments").font_(Font("Bold", 14));
			StaticText(wConfig, 500@16).string = "DMI                                     Port #         Channel       SuperCollider Patch        Output";

			// Add text fields with defaults instrument parameters
			instruments.do({
				arg item, i;

				// update interface name
				wName[i] = TextField(wConfig, 128@22);
				wName[i].string_(item[\name]).action_{|field| instruments[i][\name] = field.value};

				// update port
				wPort[i] = TextField(wConfig, 64@22);
				wPort[i].string_(item[\port]).action_{|field| instruments[i][\port] = field.value};

				// update output channel
				wOut[i] = TextField(wConfig, 32@22);
				wOut[i].string_(item[\audioOut]).action_{|field| instruments[i][\audioOut] = field.value};

				// update SC patch name
				wPatch[i] = TextField(wConfig, 240@22);
				wPatch[i].string_(item[\patch]).action_{|field| instruments[i][\patch] = field.value};

				// mono/stereo
				EZPopUpMenu.new(
					wConfig, 60@22,
					items: ["mono", "stereo"].collect{|item| item -> {instruments[i][\mode] = item}},
					// initVal:item[4],
					initAction: true
				);
			});

			// Validation Button
			Button(wConfig, Rect(20, 450, 100, 25))
			.states_([["OK"]])
			.action_(
				{
					// make sure to validate updated text fields values
					instruments.do{
						arg item, i;
						wName[i].doAction;
						wOut[i].doAction;
						wName[i].doAction;
						wPatch[i].doAction;
					};
					wConfig.close;
					~rout.next;
				}
			);

			// Yield to display the GUI
			{}.yield;

		},{
			// Procedd to next step without displaying the GUI
		}
	);


	////////////////////////////////
	// 1. server config
	////////////////////////////////

	"".postln;"--------------------------------".postln;"       Configuring Server".postln;"--------------------------------".postln;

	s = Server.local;
	("In: " ++ inDevice).postln;
	s.options.inDevice_(inDevice);
	("Input Channels: " ++ numInputBusChannels).postln;
	s.options.numInputBusChannels_(numInputBusChannels);
	("Out: " ++ outDevice).postln;
	s.options.outDevice_(outDevice);
	("Output Channels: " ++ numOutputBusChannels).postln;
	s.options.numOutputBusChannels_(numOutputBusChannels);
	s.options.sampleRate_(sampleRate);

	// resets the bus allocation counter
	s.newBusAllocators;

	// clean up
	Buffer.freeAll;
	OSCdef.freeAll;
	Window.closeAll;

	"".postln;"--------------------------------".postln;"       Server configured".postln;"--------------------------------".postln;"";


	////////////////////////////////
	// 2. initialize global variables
	////////////////////////////////

	// load the instruments source code files
	~dmiFunctions = instruments.collect({
		arg item, i;
		var dmiFunc;
		dmiFunc = (PathName(thisProcess.nowExecutingPath).parentPath ++ item[\patch]).load;
		dmiFunc.(item[\name], item[\port], item[\audioOut], item[\mode]);
	});

	"".postln;"--------------------------------".postln;"       Defining Instruments".postln;"--------------------------------".postln;"";
	instruments.do{|inst|
		[\name, \port, \audioOut, \patch, \mode].do{|i| i.post; ": ".post; inst[i].post; ", ".post;};
		"".postln;
	};
	"--------------------------------".postln;

	~dmiFunctions.do{|item, i| item[\initVariables].()};
	// ajouter une fonction pour vérifier qu'il n'a de doublon dans les OSCdefs


	////////////////////////////////
	// 3. define piece-specific functions
	////////////////////////////////

	// Function declaring SynthDef and checking duplicates
	~synthDefs = IdentitySet.new;
	~synthDefMaker = {
		arg name, ugenFunc;
		if(~synthDefs.includes(name)){
			("!!! SynthDef" + name + "already exists !!!").postln
		} {
			SynthDef(name, ugenFunc).add;
			~synthDefs.add(name)
		};
	};

	// TBC Eli Fieldsteel tutorials
	~cleanup = {
		s.newBusAllocators;
		ServerBoot.removeAll;
		ServerTree.removeAll;
		ServerQuit.removeAll;
	};

	//
	~dmiFunctions.do{|item, i| item[\specificFunctions].()};


	////////////////////////////////
	// 4. Register functions with ServerBoot/Quit/Tree
	////////////////////////////////

	// Instrument functions
	~dmiFunctions.do{|item, i| item[\functionsRegister].()};

	ServerQuit.add(~cleanup);

	// Other functions are registered in each subpatch


	////////////////////////////////
	// 5. Boot server
	////////////////////////////////

	"".postln;"--------------------------------".postln;"        BOOTING SERVER".postln;"--------------------------------".postln;

	// wait for boot function
	s.waitForBoot({
		"".postln;
		s.sync;
		"--------------------------------".postln;"         SERVER BOOTED".postln;"--------------------------------".postln;

		////////////////
		// 6a. SynthDefs
		////////////////


		// SynthDef are defined in each subpatch
		~dmiFunctions.do{|item, i| item[\synthDefServerAdd].()};

		// SynthDefs common to all instruments
		// 3 band filter - can be used with any instrument
		~synthDefMaker.(
			\triBand,
			{
				arg in=0, freq1=500, freq2=8000, gainLow=1.0, gainMid=1.0, gainHigh=1.0;
				var sig, sigLow, sigMid, sigHigh;
				sig = In.ar(in, 2); // PAR DEFAUT STEREO COMMENT CHANGER ÇA?????? UTILISER LARGEST NUMBER???
				sig = BLowShelf.ar(sig, freq1, 1, gainLow-gainMid);
				sig = BHiShelf.ar(sig, freq2, 1, gainHigh-gainMid);
				sig = gainMid.dbamp * sig;
				ReplaceOut.ar(in, sig);
			}
		);

		// // Security compressor
		// ~synthDefMaker.(\comp, {
		// 	arg in=0, out=0, thresh=0.5;
		// 	in = In.ar(in, 1); // THE SYNTH IS 24 CHANNELS!!! NEEDS TO BE ADAPTED TO THE NUMBER OF CHANNELS OF INSTRUMENTS
		// 	// REMPLACER PAR LE CHOIX ENTRE UN COMPRESSEUR MONO OU UN COMPRESSEUR STEREO
		// 	in = Compander.ar(in , in, thresh, 1.0, 0.1, 0.005);
		// 	Out.ar(out, in);
		// });

		// 2-channel compressor
		~synthDefMaker.(\compStereo, {
			arg in=0, out=0, thresh=0.5;
			var sig;
			in = In.ar(in, 2);
			sig= Compander.ar(in , in, thresh, 1.0, 0.1, 0.005);
			Out.ar(out, sig);
		});

		// 1-channel compressor
		~synthDefMaker.(\compMono, {
			arg in=0, out=0, thresh=0.5;
			var sig;
			in = In.ar(in, 1);
			sig = Compander.ar(in , in, thresh, 1.0, 0.1, 0.005);
			Out.ar(out, sig);
		});

		// 2-channel reverb
		~synthDefMaker.(\reverbStereo, {
			arg in=0, mix=0, room=0.5, damp=0.5;
			var sig;
			mix = mix.lag(0.1);
			room = room.lag(0.1);
			damp = damp.lag(0.1);
			sig = In.ar(in, 2);  // INPUT IS 2 CHANNEL
			sig = FreeVerb2.ar(
				sig[0],
				sig[1],
				mix,
				room,
				damp,
			);
			ReplaceOut.ar(in, sig); // OUTPUT WILL BE STEREO
		});

		// 1-channel reverb
		~synthDefMaker.(\reverbMono, {
			arg in=0, mix=0, room=0.5, damp=0.5;
			var sig;
			mix = mix.lag(0.1);
			room = room.lag(0.1);
			damp = damp.lag(0.1);
			sig = In.ar(in, 1);  // INPUT IS 1 CHANNEL
			sig = FreeVerb.ar(
				sig,
				mix,
				room,
				damp,
			);
			ReplaceOut.ar(in, sig); // OUTPUT WILL BE STEREO
		});

		s.sync;
		" Common SynthDefs added".postln;"--------------------------------".postln;"".postln;


		////////////////
		// 6b. Register remaining functions
		////////////////

		~dmiFunctions.do{|item, i| item[\remainingFunctions].()};

		ServerMeter(s, numInputBusChannels, numOutputBusChannels);
		FreqScope.new;
		s.plotTree;

		s.freeAll;
		s.sync;
	});
	// end of wait for boot function
};
////////////////////////////////
// enf of GUI function
////////////////////////////////

// Instantiate the GUI Routine
~rout = Routine(~mainGUI);
// 1st step
~rout.next;
"--------------------------------";
)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                      END MAIN CODE                                                         //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

