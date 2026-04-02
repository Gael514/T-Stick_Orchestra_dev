// s.boot;
(
d = Dictionary.newFrom([
	\p1, [ 0.0, 1.0, 0.5, 0.0],
	\p3, [ 1.0, 1.0, 1.0, 1.0],
	\p4, [ 0.0, 0.0, 0.0, 0.0],
]);

~coll = [\p1, \p3, \p4].collect{|i| d[i]};
~coll = ~coll.flat;

~buf = Buffer.loadCollection(s, ~coll);

c = Bus.control(s, 1);
p = Bus.control(s, 4);

z = {
	arg in;
	var params, base, trig;
	in = In.kr(c, 1).round(1);
	trig = Changed.kr(in);
	base = in * d[\p1].size;
	params = Array.fill(d[\p1].size,{|i|
		Latch.kr(
			BufRd.kr(1, ~buf, base + i),
			trig
		)
	});
	Out.kr(p, params);
}.play;

Stethoscope(s, 1, c.index, rate:\control);
Stethoscope(s, 4, p.index, rate:\control);

)

{BufRd.kr(1, ~buf, 2).poll}.play

c.set(0)
c.set(1)
c.set(2)
c.set(0)


~dmiFunctions[0].postcs
~dmiFunctions[0][\mappingGrp]
~dmiFunctions[0][\sortedTimbre]
~dmiFunctions[0][\synthParam].postcs
~dmiFunctions[0][\synthParam].class
~dmiFunctions[0][\busSynth]["presetSel"]
~dmiFunctions[0][\busSynth]["timbre"].numChannels
~dmiFunctions[0][\busSynth]["timbre"]
~dmiFunctions[0][\bufPreset].plot
~dmiFunctions[0][\bufPreset].numFrames / 48

Stethoscope(s, 1, c.index, rate:\control);
Stethoscope(s, 4, p.index, rate:\control);
(
Stethoscope(s, 1, 122, rate:\control);
Stethoscope(s, 48, 74, rate:\control);
)

Stethoscope(s, 48, 74, rate:\control);

~dmiFunctions[0][\numPartials]

~dmiFunctions[0][\timbre].postcs
~dmiFunctions[0][\timbre].keys
~dmiFunctions[0][\timbre].keys.keyAt(6)
~dmiFunctions[0][\timbre].size
~dmiFunctions[0][\timbre].asArray[0]
~dmiFunctions[0][\timbre][\bell]
~dmiFunctions[0][\timbre][\p5rumble].size
~dmiFunctions[0][\timbre][\p6rumblebis].size
~dmiFunctions[0][\timbre][\p1drone].size
~dmiFunctions[0][\timbre].keys
~dmiFunctions[0][\busSynth]["presetSel"].get
~dmiFunctions[0][\busSynth]["timbre"].get
~dmiFunctions[0][\busSynth]["timbre"]
~dmiFunctions[0][\busSynth]["timbre"].numChannels
~dmiFunctions[0][\busSynth]["presetSel"].set(0)
~dmiFunctions[0][\busSynth]["presetSel"].set(1)
~dmiFunctions[0][\busSynth]["presetSel"].set(4)
~dmiFunctions[0][\busSynth]["presetSel"].set(10)
~dmiFunctions[0][\busSynth][\fx]
~dmiFunctions[1][\busSynth][\fx]

z = Stethoscope(s, ~dmiFunctions[0][\busSynth]["timbre"].numChannels, ~dmiFunctions[0][\busSynth]["timbre"].index, rate: \control)
z = Stethoscope(s, ~dmiFunctions[0][\busSynth]["presetSel"].numChannels, ~dmiFunctions[0][\busSynth]["presetSel"].index, rate: \control)
z = Stethoscope(s, ~dmiFunctions[0][\busSynth]["hiPartialsMod"].numChannels, ~dmiFunctions[0][\busSynth]["hiPartialsMod"].index, rate: \control)
z = Stethoscope(s, ~dmiFunctions[0][\busSynth]["partialsAmod"].numChannels, ~dmiFunctions[0][\busSynth]["partialsAmod"].index, rate: \control)
z = Stethoscope(s, ~dmiFunctions[0][\busSynth]["partialsFmod"].numChannels, ~dmiFunctions[0][\busSynth]["partialsFmod"].index, rate: \control)
z = Stethoscope(s, ~dmiFunctions[0][\busDmi]["TStick_516/raw/gyro"].numChannels, ~dmiFunctions[0][\busDmi]["TStick_516/raw/gyro"].index, rate: \control)

[ \glass, \drone2, \nuage, \bell ][3]


(
var instrument = Dictionary.newFrom([\numPartials, 15]);

SynthDef(\multiFiltResonCheck, {
	arg out=0, freq=220, harmo=1.0, rq=0.1, atk=0.1, decay=0.1, sus=0.7, ampMat=1.0, envSel=0, amp=0.7, gate=1, pos=0.0, dustDens=50000;
	var envT, envN, env, sigMat, sigFilt, freqMax, peak;

	// envT = EnvGen.kr(Env.asr(atk, 1.0, \rels.kr( Array.fill(~numPartials, 1) )), gate); // plusieurs gates????
	// envN = EnvGen.kr(Env.perc(atk, \rels.kr( Array.fill(~numPartials, 1) )));
	// env = Select.kr(envSel, [envN, envT]);

	peak = atk.lincurve(0.001, 0.5, 1, 0.7); // AFFINER LES COEFFICIENTS
	env = EnvGen.kr(Env.adsr(atk, decay, sus, \rels.kr( Array.fill(instrument[\numPartials], 10) ), 1.0), gate, timeScale: \timeScale.kr(Array.geom(instrument[\numPartials], 1.0, 1.0)));
	// env[0].poll;
	// sigMat = WhiteNoise.ar;
	sigMat = Dust2.ar(dustDens);
	sigFilt = Mix.ar(
		BPF.ar(
			sigMat,
			Array.series(instrument[\numPartials], freq, freq * harmo) * \freqMuls.kr( Array.fill(instrument[\numPartials], 1)), // frequencies
			rq,
			\amps.kr( Array.fill(instrument[\numPartials], 1/instrument[\numPartials]) ) * ampMat
		) * env
	); //rq multiplié par amps (ou autre Array)
	freqMax = freq * ( (instrument[\numPartials]-1)*harmo +1);
	sigFilt = BLowPass.ar(sigFilt, 0.5*freqMax, 0.3); // RETRAVAILLER!!!
	// Libérer le synth seulement quand toutes les enveloppes sont closes
	FreeSelf.kr(DetectSilence.ar(sigFilt, -100.dbamp, time: 1.0)); // Freeself contrôlé par Mix(sig): 1 seul signal!
	Out.ar(out, PanAz.ar(2, sigFilt, pos, amp) );
}).add;
)


// test Trame
(
~numPartials = 15;
~drone = Synth(\multiFiltReson, [
	// spectrum
	\dustDens, 20000,
	\freq, 55,
	\harmo, 1.2,
	\freqMuls, Array.rand(~numPartials, 0.99, 1.01),
	\rq, 0.001,
	// \rqs, Array.fill(~numPartials, 0.001),
	\amps, Array.geom(~numPartials, 1.0, 0.7).normalize,
	// dynamics
	\atk, 0.01,
	\rels, Array.fill(~numPartials, {5.0 * 1.33.rrand(1.33.reciprocal)} ),
	\ampMat, 30.dbamp,
	// \envSel, 1,
	\amp, 1.7,
	// output
	\out, 0,
	\pos, 0
]);
)
~drone.set(\gate, 0)




[0.5, 2.3, 0, 1].normalize.maxItem
[0.5, 2.3, 0, 1].maxItem

// essai de mappage pour le controle d'octave avec un brush sur les strips 0 à 3
// octave initalement à 1 (monter à 2 puis 4, descendre à 0.5, puis 0.25)
(
var interface = "TStick_516";
var octave = 0;
// normalization values
var min = Array.fill(3, 0);
var max = [801.6, 1355.8, 1297.4];
~bus = Bus.control(s, 1);
t = {
	arg highUp = 0.15, lowUp = 0.05, highDown = -0.15, lowDown = -0.05;
	var brush = In.kr(~dmiFunctions[0][\busDmi][interface ++ "/instrument/brush"], 1);
	var octCtrl = In.kr(~dmiFunctions[0][\busDmi][interface ++ "/raw/capsense"], 3);
	var up, down, temp, arm = True;
	octCtrl = octCtrl.linlin(min, max, 0, 1);
	temp = Mix(octCtrl).roundUp * brush;
	if( (arm == true) && (temp > highUp) ) {
		~bus.get{|current| ~bus.set(current + 1)};
		arm = false;
	} {
		arm == true;
	};
	// brush.round(0.01).poll;
	temp.poll;

	Out.kr(0, brush);
}.play();

)
t.free;

(
var interface = "TStick_516";
interface.postln;
~dmiFunctions[0][\busDmi].postln;
~dmiFunctions[0][\busDmi][interface ++ "/instrument/brush"].postln;
)


