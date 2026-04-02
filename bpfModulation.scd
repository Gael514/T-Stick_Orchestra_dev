// Modulating mid-shelf filter
(
var numChan = 1;
b = {
	// gains are in dB
	arg in=0, freq1=500, freq2=8000, gainLow=0.0, gainMid=0.0, gainHigh=0.0;
	var sig, sigLow, sigMid, sigHigh;
	sig = In.ar(in, numChan);
	sig = BLowShelf.ar(sig, freq1, 1, gainLow-gainMid);
	sig = BHiShelf.ar(sig, freq2, 1, gainHigh-gainMid);
	sig = gainMid.dbamp * sig;
	ReplaceOut.ar(in, sig);

}.play(addAction: \addToTail);
)
(
c = {
	arg out = 0, amp = 0.4;
	Out.ar(out, WhiteNoise.ar(amp));
}.play(addAction: \addToHead);
)

// comparer à un BPF à rq large, appliqué à un white noise
b.free
c.free
b.set(\gainLow, -60);
b.set(\gainLow, -60);




// Combination of a LPF and a HPF
(
var numChan = 1;
b = {
	//
	arg in=0, freq1=20, freq2=20000;
	var sig, sigLow, sigMid, sigHigh;
	sig = In.ar(in, numChan);
	sig = 0.5 * (HPF.ar(sig, freq1) + LPF.ar(sig, freq2));
	ReplaceOut.ar(in, sig);
}.play(addAction: \addToTail);
)
b.set(\freq1, 500, \freq2, 8000);
b.set(\freq1, 20, \freq2, 20000);
b.set(\freq1, 8000, \freq2, 15000);
b.set(\freq1, 8000, \freq2, 5000);

~modBus = Bus.control(s, 2);
(
m = {
	var mod;
	mod = [LFNoise1.kr(1).range(20, 8000), LFNoise1.kr(1).range(8000, 20000)];
	Out.kr(~modBus, mod);
}.play;
)
m.free;
b.map(\freq1, ~modBus.subBus(0));
b.map(\freq2, ~modBus.subBus(1));

c.free;

// compare with a BPF
(
~bpf = {
	arg f = 5000, rq = 1, amp = 0.7;
	var sig;
	sig = BPF.ar(WhiteNoise.ar(amp), f, rq);
	Out.ar(1, sig);
}.play();

~comboHpfLpf = {
	arg amp = 0.7, freq1=2500, freq2=7500;
	var sig;
	sig = WhiteNoise.ar(amp);
	sig = LPF.ar(HPF.ar(sig, freq1), freq2);
	Out.ar(0, sig);
}.play();
)
~bpf.set(\f, 200, \rq, 2);
~comboHpfLpf.set(\freq1, 100, \freq2, 500);

// combine modulation with accX up/down
// comment déplacer lecdg
// le curve de lincurve lié à accX
(
{

}.play()
)
{ LFNoise1.kr(10).lincurve(-1, 1, 10, 20, 4) }.plot(2)
{ LFNoise1.kr(10).lincurve(-1, 1, 10, 20, -4) }.plot(2)
{ LFNoise1.kr(10).lincurve(-1, 1, 10, 20, Line.kr(-4, 4, 4)) }.plot(4)
{ LFNoise1.kr(2).lincurve(-1, 1, 10, 20, Line.kr(-4, 4, 16)).lag(0.25) }.plot(16)

// freq1 LFNoise1.kr(gyro.abs.lincurve(?, ?, 0.5, 5, ?)).lincurve(-1.0, 1.0, 20, 4000, accX.range)
// PENSER À LA POSITION NATURLLE DU T-STICK
// VALEURS DE GYRO TYPIQUES ??? MAX ???
// CORRECTION dB???

// loFreq
// speed corresponds to sum of gyro absolute value
speed = gyro.abs.sum
// calcule
azimuth = accX.linlin(-10, 10, -4, 4)
LFNoise1.kr(speed.linlin(0.2, 0.8, 0.5, 5)).lincurve(-1, 1, 20, speed.linlin(0.2, ~gyrMax, 20, 4000, \min), aziCurve )

[0.1, -2, 0].abs.sum

// si je choisis une note
// comment géréer les accords...?
//
// 1 strip touché -> single note / centroid no effect / spread -> duplicate 8ba + 8va
// 2 strips touched -> 2 single notes if centroid < ??? / spread -> duplicate
//



