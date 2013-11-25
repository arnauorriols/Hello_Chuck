/* Returns the duration of the quarter given the beats-per-minute value */
fun dur setTempo(int bpm) {
    <<<bpm, bpm/60, (1.0/(bpm / 60.0))>>>;
    return ((1.0/(bpm / 60.0))::second);
}

fun float getConstant(float first, float secnd) {
    return (first/secnd);
}

fun dur roundDur(dur durToRound, int greatestDivisor) {
    Std.ftoi(Math.round(durToRound / samp)) => int roundedDur;
    roundedDur - (roundedDur % greatestDivisor) => roundedDur;
    return roundedDur::samp;
}

fun void screamGain(Gain gainKnob, string label) {
    if (Std.fabs(gainKnob.last()) > gainKnob.gain()) {
        <<<"ATTENTION!", label, "is too loud (", gainKnob.last(),")">>>;
    }
}

fun void screamDac() {
    if (Std.fabs(dac.last()) > 1) {
        <<<"ERROR! DAC too loud (", dac.last(), ")">>>;
    }
}

fun int changeOctave(int midiNote, int octaveDistance) {
    return (midiNote + (12 * octaveDistance));
}

fun float centsInterval(float initialFreq, int cents) {
    return (initialFreq * Math.pow(2, (cents/1200.0)));
}

// SCALE DEFINITION (Db Phrygian mode)
[49, 50, 52, 54, 56, 57, 59, 61] @=> int midiScale[];

/* DURATIONS DEFINITION
 * Requirement: quarter at 0.75 second
 */
0.75 => float quarterSec;
getConstant((setTempo(140)/second), quarterSec) => float constant;
roundDur((quarterSec * constant)::second, 16) => dur quarter;
quarter * 4 => dur measure;
measure / 2 => dur half;
quarter / 2 => dur eighth;
quarter / 3 => dur triplet;
eighth / 2 => dur sixteenth;
4::samp => dur beattime;
<<<quarter/second>>>;
// sound chain

// Master sound chain: rev, master gain and to dac
Pan2 master => dac;
JCRev revl => master.left;
JCRev revr => master.right;
0.75 => master.gain;
0.04=> revl.mix;
0.04=> revr.mix;

Noise n => LPF nFilter => Pan2 nPan;
nPan.left => revl;
nPan.right => revr;
-0.9 => nPan.pan;
60 => int nFiltFreq;
10 => int nFiltQ;
0.1 => n.gain;
nFiltFreq => nFilter.freq;
nFiltQ => nFilter.Q;

// GROOVE filter: to control open/close sound of the groove
LPF grooveFilter => Pan2 groovePan;
groovePan.left => revl;
groovePan.right => revr;
0.2 => groovePan.pan;
22000 => int GFFreq;
8 => int GFQ;
GFFreq => grooveFilter.freq;
GFQ => grooveFilter.Q;

/* BASS OSCS
 *  - 2 couples of Osc (car/detunedCar), each with different low-frequency filter, modulated
 *    with a SinOsc (mod and mod2) to achieve 2 different wobble effects.
 *  - 1 SinOsc reinforcing the bass without distortion.
 */
SqrOsc car;
SqrOsc detunedCar;
SawOsc car2;
SawOsc detunedCar2;
SinOsc subBass;
SinOsc mod;
SinOsc mod2;

// Bass sound chain
Gain bassGain => grooveFilter;
car => ADSR env =>  LPF filter => bassGain;
detunedCar => env;
car2 => ADSR env2 =>  LPF filter2 => bassGain;
detunedCar2 => env2;
subBass => bassGain;

// Bass osc gain assign
0.4 => bassGain.gain;
0.08 => car.gain => detunedCar.gain;
0.15 => car2.gain => detunedCar2.gain;
(1 - ((car.gain()*2) + (car2.gain()*2))) +  0.1 => subBass.gain;

// ADSR envelope setting for the bass Osc
(measure * 0.08, measure * 0.5, 0.7, measure*0.4) => env.set;
(measure * 0.0001, measure * 0.7, 0.001, measure*0.0001) => env2.set;

/* Chuck mod and mod2 to backhole. This way we can extract the data of these
 * sinewaves and modulate the filters of the bass' sound chain with this data.
 * They have an ADSR to manage the envelope of the filter's modulation.
 */
mod => ADSR filterEnv => blackhole;
mod2 => ADSR filterEnv2 => blackhole;

3 / (quarter/second) => mod.freq;       // Wobble in triplets
750 => mod.gain;
5 / (quarter/second) => mod2.freq;      // Wobble in quintlets (¿?)
900 => mod2.gain;

// ADSR envelope setting for the low pass filter modulations
(measure * 0.6, measure * 0.1, 1, measure*0.4) => filterEnv.set;
(measure * 0.2, measure * 0.7, 0.001, measure*0.0001) => filterEnv2.set;

900 => int filterCutoff;
1400 => int filter2Cutoff;
4 => filter.Q;
3 => filter2.Q;


/* DRUMS SOUND CHAIN
 * Kick, snare, hihat and clap. Each one with its own delay (for swinging a
 * little bit) and different filters/shifters to achieve the expected sound
 */
Gain drumsGain => grooveFilter;
SndBuf kick => LPF kickFilter => PitShift kickShift => Delay kickDelay => drumsGain;
SndBuf snare => Delay snareDelay => drumsGain;
SndBuf hihat => PitShift hiShift => Delay hiDelay => drumsGain;
SndBuf clap => JCRev clapRev => Delay clapDelay => drumsGain;

me.dir() + "/audio/kick_05.wav" => kick.read;
me.dir() + "/audio/snare_01.wav" => snare.read;
me.dir() + "/audio/hihat_03.wav" => hihat.read;
me.dir() + "/audio/clap_01.wav" => clap.read;

kick.samples() => kick.pos;
snare.samples() => snare.pos;
hihat.samples() => hihat.pos;
clap.samples() => clap.pos;

//4Gains and rates for drums samples
0.35 => drumsGain.gain;
0.7 => kick.gain;
2 => kick.rate;
1.4 => snare.gain;
.5 => snare.rate;
1.7 => hihat.gain;
2.0 => hihat.rate;
0.4 => clap.gain;
0.7 => clap.rate;

// Other effects for drums:
80 => kickFilter.freq;
 4 => kickFilter.Q;
1.2 => kickShift.shift;
2.5 => hiShift.shift;
0.06 => clapRev.mix;

// Delays for drums
sixteenth/2 => snareDelay.max => snareDelay.delay;
sixteenth/2.5 => kickDelay.max => kickDelay.delay;
sixteenth/3 => hiDelay.max => hiDelay.delay;
sixteenth/1 => clapDelay.max => clapDelay.delay;

// MELODY SOUND CHAIN
Moog melody => Gain melodyGain => JCRev melodyRev => Delay mDelay => Pan2 mPan;
mPan.left => revl;
mPan.right => revr;

-0.3 => mPan.pan;

0.5 * triplet => mDelay.max =>  mDelay.delay;
0.2 => melodyRev.mix;
0.8 => melodyGain.gain;
0.8 => melody.gain;
<<<melody.vibratoFreq(), melody.vibratoGain()>>>;
0.5 => melody.filterQ;
0.7 => melody.filterSweepRate;
0.02 => melody.vibratoGain;
/* Drums pattern definition:
 * resolution: 16/measure (sixteenth note)
 * 2D array:
 *      [[kick],[snare],[clap],[hihat]]
 */
[[[1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0],
  [0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0],
  [0, 0, 0, 0,  0, 0, 1, 1,  0, 0, 0, 0,  0, 0, 1, 0],
  [0, 0, 1, 0,  0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0]],
  
 [[1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0,  0, 0, 0, 0],
  [1, 0, 0, 0,  0, 0, 1, 0,  0, 0, 1, 0,  0, 0, 1, 0],
  [0, 0, 0, 0,  0, 0, 0, 1,  1, 0, 0, 1,  1, 0, 0, 1],
  [1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  1, 1, 0, 0]]]@=> int drumsPattern[][][];

fun void playDrums(int _beatInLoop, int pattern[][]){

    _beatInLoop % Std.ftoi(measure/beattime) => int beatInMeasure;
    if (beatInMeasure % (sixteenth/beattime) == 0.0){
        Std.ftoi((beatInMeasure % (measure/beattime))
                 / (sixteenth/beattime)) => int sixteenthInMeasure;

        if (pattern[0][sixteenthInMeasure] == 1) {
            0 => kick.pos;
        }
        if (pattern[1][sixteenthInMeasure] == 1) {
            0 => snare.pos;
        }
        if (pattern[2][sixteenthInMeasure] == 1) {
            0 => clap.pos;
        }
        if (pattern[3][sixteenthInMeasure] == 1) {
            0 => hihat.pos;
        }
    }
}

[[-1, -1, -1,   -1, -1, -1,   -1, -1, -1,   4,  4,  4,
   6,  6,  6,    6,  6,  6,    6,  6,  7,   7,  7,  7,
   6,  6,  6,    6,  6,  6,   -1, -1, -1,  -1,  5,  4,
   3,  3,  3,    3,  3,  3,    2,  2,  2,   2,  2,  2],

 [ 4,  4,  4,    4,  4,  4,    4,  4,  4,   4,  4,  4,
  -1, -1, -1,   -1, -1, -1,   -1, -1, -1,   4,  4,  4,
   6,  6,  6,    6,  6,  6,   -1, -1, -1,  -1,  5,  4,
   3,  3,  3,    3,  3,  3,    2,  2,  2,   2,  2,  2]] @=> int melodyNotes[][];


fun void playMelody(int beatInLoop, int notes[]) {
   if (beatInLoop % Std.ftoi(triplet/beattime) == 0.0) {

       Std.ftoi(beatInLoop / (triplet/beattime)) => int tripletInLoop;
       if (notes[tripletInLoop] >= 0){
           if (tripletInLoop != 0) {
               if (notes[tripletInLoop] != notes[tripletInLoop-1]){
                   Std.mtof(midiScale[notes[tripletInLoop]]) => melody.freq;
                   Math.random2f(0.7, 0.8) => melody.noteOn;
               }
           } else {
               if (beatInLoop == 0) {
               Std.mtof(midiScale[notes[tripletInLoop]]) => melody.freq;
               0.7 => melody.noteOn;
               }
           }
       } else {
           0.01 => melody.noteOff;
       }
   }
}




/* MAIN PROGRAM */
now => time start;
start + 31::second => time maxComp;
0 => int beat;

for(0 => int bassLoop; bassLoop < 4; bassLoop++){
    for(0 => int beat; beat < 4 * (measure/beattime); beat++)
{
    beat % Std.ftoi(4 * (measure/beattime)) => int beatInLoop;
    playDrums(beat, drumsPattern[0]);

    0.0 => float freqToPlay;

    if (beat == 0){
        Std.mtof(changeOctave(midiScale[4], -1)) => freqToPlay;
        freqToPlay => car.freq;
        centsInterval(freqToPlay*2, -22)  => detunedCar.freq; // -22 cents
        freqToPlay => car2.freq;
        centsInterval(freqToPlay, 29) => detunedCar2.freq;  // + 29 cents
        freqToPlay/2 => subBass.freq;
        1 => env.keyOn => env2.keyOn;
        1 => filterEnv.keyOn;
        1 => filterEnv2.keyOn;
    } else if (beat == Std.ftoi(measure/beattime)){
        Std.mtof(changeOctave(midiScale[4], -1)) => freqToPlay;
        freqToPlay => car.freq;
        centsInterval(freqToPlay*2, -22)  => detunedCar.freq;
        freqToPlay => car2.freq;
        centsInterval(freqToPlay, 29) => detunedCar2.freq;
        freqToPlay/2 => subBass.freq;
        1 => env.keyOn => env2.keyOn;
        1 => filterEnv.keyOn;
        1 => filterEnv2.keyOn;
    } else if (beat ==  2* Std.ftoi(measure/beattime)){
        centsInterval(Std.mtof(changeOctave(midiScale[5], -1)), -30) => freqToPlay;
        freqToPlay => car.freq;
        centsInterval(freqToPlay*2, -22)  => detunedCar.freq;
        freqToPlay => car2.freq;
        centsInterval(freqToPlay, 29) => detunedCar2.freq;
        freqToPlay/2 => subBass.freq;
        1 => env.keyOn => env2.keyOn;
        1 => filterEnv.keyOn;
        1 => filterEnv2.keyOn;
    } else if (beat == 3 * (measure/beattime)){
        centsInterval(Std.mtof(changeOctave(midiScale[3], -1)), -45) => freqToPlay;
        freqToPlay => car.freq;
        centsInterval(freqToPlay, -22)  => detunedCar.freq;
        freqToPlay => car2.freq;
        centsInterval(freqToPlay, 29) => detunedCar2.freq;
        freqToPlay/2  => subBass.freq;
        1 => env.keyOn => env2.keyOn;
        1 => filterEnv.keyOn;
        1 => filterEnv2.keyOn;

    } else if (beatInLoop % (measure/beattime) == (measure/beattime) -
    Std.ftoi(quarter/beattime)) 
    {
        1 => env.keyOff;
        1 => env2.keyOff;
        1 => filterEnv.keyOff;
        1 => filterEnv2.keyOff;
    }

    filterEnv.last() + filterCutoff   => filter.freq;
    filterEnv2.last() + filter2Cutoff   => filter2.freq;
    screamDac();
    //screamGain(master, "master");
    //screamGain(bassGain, "bassGain");
    //screamGain(drumsGain, "drumsGain");
    beattime => now;

    if (bassLoop == 1) {
        if (beat % (sixteenth/beattime) == 0){
            2 => grooveFilter.Q;
            5.2 * Math.pow((beat / (sixteenth/beattime)) - 64, 2) + 600 => grooveFilter.freq;
            groovePan.pan() + (0.25 / 64) => groovePan.pan;
        }
    } else if (bassLoop == 2) {
        1 => grooveFilter.Q;
        0.7 => grooveFilter.gain;
        playMelody(beat, melodyNotes[0]);
    } else if (bassLoop == 3) {
        if (beat % (sixteenth/beattime) == 0){
            nFilter.freq() + 70 => nFilter.freq;
            n.gain() + (0.55 / 64) => n.gain;
            nPan.pan() + (0.9 / 64) => nPan.pan;
            8 => nFilter.Q;
            0.1 => nFilter.gain;
            grooveFilter.freq() + 20 => grooveFilter.freq;
        }
        playMelody(beat, melodyNotes[1]);
    }
}
}
GFFreq => grooveFilter.freq;
GFQ => grooveFilter.Q;
1 => grooveFilter.gain;
nFiltFreq => nFilter.freq;
nFiltQ => nFilter.Q;
0 => nFilter.gain;
0.1 => groovePan.pan;
-0.4 => mPan.pan;


for(0 => int beat; now < maxComp; beat++) {
    if (beat < (4 * (quarter/beattime))) {
        if (beat == 0) {
            Std.mtof(midiScale[0]) => melody.freq;
            0.8 => melody.noteOn;
        }
        playDrums(beat, drumsPattern[1]);
    } else if (beat == 4 * (quarter/beattime)) {
        0 => kick.pos;
        0 => snare.pos;
        0 => clap.pos;
        0 => hihat.pos;
        .1 => melody.noteOff;
        0 => subBass.gain;

    }

beattime => now;
}
<<<now/second>>>;
