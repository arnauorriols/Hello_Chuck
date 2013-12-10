// Assignment_7_Chuck_Rameau

// Score file. Control global settings and time

HarmCtl harmony;
RhythmCtl rhythm;

harmony.setScale("C 2", "ionian");
rhythm.setMeter(4, 4);  // 4/4 meter, assign beat to quarter
rhythm.setTempo(0.625); // beat is 0.625 seconds
rhythm.structureCtl(30, 3, 1, 4);

<<<"","">>>;
<<<"CHUCK RAMEAU HOUSE REMIX. After J. P. Rameau (XVIIth century)", "">>>;
<<<"-------------------------------------------------------------", "">>>;
<<<"","">>>;
<<<"Fundamental:", harmony.fundamental, "mode:", harmony.mode[0]>>>;
<<<"Tempo:", rhythm.bpm, "Meter:", rhythm.beatsPerMeasure + "/" + rhythm.beatAssign>>>;
<<<"Total duration:", rhythm.composition/second, "sections:",
rhythm.numSections, "measures per section:", rhythm.measuresPerLoop>>>;
rhythm.checkStructure();
Noise n => LPF filter => dac;

1000 => filter.freq;
1 => filter.Q;
0.004 => n.gain;

me.dir() => string path;
now => time start;
Machine.add(path + "/drums.ck") => int drumsID;
// Add lead pad
Machine.add(path + "/lead.ck") => int leadID;
rhythm.measure * 4 + rhythm.quarter=> now;
// Add piano
Machine.add(path + "/piano.ck") => int pianoID;
rhythm.composition - (rhythm.measure * 4 + rhythm.half) => now;
Machine.remove(drumsID);
//Machine.remove(leadID);
Machine.remove(pianoID);
rhythm.measure => now;
Machine.remove(leadID);
<<<(now-start) / second, "seconds">>>;
