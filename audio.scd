(
{ | dur = 0.15, atk = 0.005, amp = 1 |
	SinOsc.ar(
		EnvGen.ar( Env(\freq_l.kr([2960, 70, 90]), \freq_d.kr([0.07, 0.2]), \freq_c.kr([-13, -1]),) ),
		mul:amp * EnvGen.ar( Env.perc( atk, dur - atk, curve: \amp_c.kr([-1, 6])), doneAction: 2 );	
	) ! 2;
}.asSynthDef.name_("pkick").add;

{ | atk = 0.01, dur = 0.15, freq = 50, amp=0.8 |
	BPF.ar(LFSaw.ar(freq), freq, 2, mul: EnvGen.ar( Env.perc( atk, dur-atk, amp, 6 ), doneAction: 2 )) ! 2;
}.asSynthDef.name_("pbass").add;

{ | atk = 0.01, dur = 0.15, freq = 50, amp = 0.8, index = 10, factor = 1.3 |
	PMOsc.ar(freq, freq*factor, index, mul: amp * EnvGen.ar( Env.perc( atk, dur - atk ), doneAction: 2 )) ! 2;
}.asSynthDef.name_("pbazz").add;
)

(
var vz = NetAddr("127.0.0.1", 25825);
Ppar([
	Pbind(*[
		instrument: \pkick,
		delta: 1,
		dur: Pfunc({ thisThread.clock.beatDur }) / 4,
		amp: Pseq([Pseq([1], 16), Pseq([0.9, 1], 8), Pseq([1], 16), Pseq([0.9!3, 1].flat, 8)], inf) * 0.8,
		freq_l: Pstutter(Prand(2.pow((1..4)),inf), Pseq({`[1100.rrand(2960), 60.rrand(90), 50.rrand(120)]}!40, inf)),
		vz: Pfunc({ |e| { vz.sendMsg('ping', 0, e.dur*4, e.amp, e.freq_l[2], e.freq_l.asString) }.defer })
	]),
	Pbind(*[
		instrument: \pbass,
		delta: 1/4,
		dur: Pkey(\delta) * Pfunc({ thisThread.clock.beatDur }),
		freq: Pseq([\r,50,80,70], inf)*Pstutter(16, Pwhite(1.0,1.2)),
		amp:0.8,
		vz: Pfunc({ |e| { e.isRest.not.if({ vz.sendMsg('ping', 1, e.dur, e.amp, e.freq.pow(2), '') }) }.defer }),
	]),
	Pbind(*[
		instrument: \pbazz,
		delta: Pstutter(Pseq(#[4,1],inf),Pseq(#[4,2,1],inf)),
		dur: Pkey(\delta) * Pfunc({ thisThread.clock.beatDur }),
		freq: Pseq([50,100,200,400], inf)*Pstutter(Pseq(#[4,1,2],inf), Pwhite(1.0,3.0)),
		amp:0.2,
		factor: Pwalk([4/3,5/3,8/3,9/3], Pseq([1,2,-3],inf)),
		vz:Pfunc({ |e| { vz.sendMsg('ping', 2, e.dur, e.amp, e.freq, [e.factor].asString) }.defer(thisThread.clock.beatDur/16) }),
		timingOffset: 1/16
	])
]).play(TempoClock(142/60), quant:[1])
)