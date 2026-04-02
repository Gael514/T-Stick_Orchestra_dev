// for low speeds, reduce the width
// max duration for the high or low value 0.25 second
// width / speed
// slowest 0.25s mod every second
// fastest width = 0.5, speed = 18 Hz
0.5/18 // duration28 ms....

b = Bus.control(s, 1);
(
a = {
	// arg vibr = [0, 0];
	var vibr, speed, mod, width;
	vibr = \in.kr([0, 0]);
	speed = vibr.lincurve(0, 0.5, 8, 18, 0, nil);
	width = speed.lincurve(8, 18, 0.1, 0.5);

	mod = LFPulse.kr(speed * LFNoise1.kr(1.0!2).range(0.9, 1.1), 0, width).range(1, [(vibr[0] > 0).if(2, 1), (vibr[1] > 0).if(2/3, 1)]);
	mod = mod[0] * mod [1];
	mod = Lag.kr(mod, 0.01);
	// Out.kr(0, mod[0]);
	// Out.kr(1, mod[1]);
	Out.kr(b, mod);
}.play();
)
a.set(\in, [0.05, 0])
a.set(\in, [0, 0.5])
a.set(\in, [0.1, 0.5])
a.set(\in, [0.5, 0])
a.set(\in, [0.5, 0.2])
a.set(\in, [0.5, 0.5])
a.set(\in, [0, 0])
a.free;

(
z = {
	arg freq = 220, mod = 1;
	var snd;
	// snd = SinOsc.ar(freq * mod) * 0.2;
	snd = VarSaw.ar(freq * mod, width: 0.5) * 0.2;
	Out.ar(0, snd);
}.play();
)
z.map(\mod, b);
z.set(\freq, 880)
z.free;

// amp modulator - tronçonnage
(
t = {
	// arg vibr = [0, 0];
	var vibr, speed, mod, width;
	vibr = \in.kr([0, 0]);
	speed = vibr.lincurve(0, 0.5, 8, 18, 0, nil);
	width = speed.lincurve(8, 18, 0.1, 0.5);

	mod = LFPulse.kr(speed * LFNoise1.kr(1.0!2).range(0.9, 1.1), 0, width).range(1, [(vibr[0] > 0).if(2, 1), (vibr[1] > 0).if(2/3, 1)]);
	mod = mod[0] * mod [1];
	mod = Lag.kr(mod, 0.01);
	// Out.kr(0, mod[0]);
	// Out.kr(1, mod[1]);
	Out.kr(b, mod);
}.play();
)


