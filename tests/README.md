# tests/

Test scripts for `pamLtsa`. Each test is a standalone MATLAB
script — run individually from the MATLAB command window or by pressing F5.

No automated test runner yet. Add one if the suite grows.

---

## Tests

### `test_wavFolderToLtsa_regression.m`
**Functions:** `wavFolderToLtsa`  
**Rationale:** `wavFolderToLtsa` was refactored from three diverged copies
(`wavFolderToLtsa`, `wavFolderToLtsa_parallel`, `wavFolderToLtsa_clickRemove`).
This test verifies the unified function produces identical output to the
pre-refactor reference LTSA for a 300-hour subset of Kerguelen 2014.  
**Data required:** `S:\work\250Hz\Kerguelen2014\` wav folder;
`S:\manuscripts\2024-12-AWR-CallDensity\ltsa\kerguelen2014_3600s_1Hz.ltsa.mat`  
**Expected result:** `[PASS] ltsa values match` with max relative error = 0.

---

### `test_wavFolderToLtsa_clickRemoval.m`
**Functions:** `wavFolderToLtsa`, `calibrateLtsa`, `attachLtsa`, `plotCalibratedLtsa`  
**Rationale:** Verifies that the `clickThreshold`/`clickAmount` options
reduce broadband PSD on a dataset with known echosounder contamination.
Kombi003 2021 is ideal for this — the hydrophone was co-located with an
echosounder for the full deployment. Also exercises the calibration
pipeline (`attachLtsa` → `calibrateLtsa`) on freshly computed rather than
loaded LTSA data.  
**Data required:** `S:\work\250Hz\kombi003_2021\` wav folder (250 Hz version).  
**Expected result:** `[PASS] Click removal reduced broadband PSD by ~7 dB`
(exact value will vary slightly with threshold and time window).

---

### `test_removeClicks_kombi.m`
**Function:** `removeClicks`  
**Rationale:** Manual visual validation of click suppression on real data.
Loads 300 s of audio from Kombi003 2021, which contains regular echosounder
pulses (~1 Hz, high amplitude) and seismic airgun shots (~20 s spacing,
low-frequency energy from a distant survey vessel). Produces a three-panel
figure: raw vs cleaned waveform overlay, raw spectrogram, and cleaned
spectrogram.

With default settings (`threshold=3, amount=1000`), the echosounder is
suppressed as intended. However, broadband artefacts appear at the airgun
shot times in the cleaned audio — the airguns are below threshold in the
raw recording, but once the echosounder is removed the local RMS drops and
the airgun samples can exceed the recalculated threshold. This is a
documented limitation of threshold-based gating with multiple simultaneous
impulsive noise sources of different character.

**Data required:** `w:\LongTermRecording2002_present\KOMBI003_2021\25_2021-03-08_03-00-00.wav`  
**Expected result:** Visual inspection — echosounder columns suppressed in
cleaned spectrogram, broadband artefacts visible at ~20 s intervals.

---

### `test_wavFolderToLtsa_parallelThreshold.m`
**Functions:** `wavFolderToLtsa`  
**Rationale:** Empirically determines the optimal `parallelThreshold` for
`wavFolderToLtsa` on the current machine. Measures pool startup cost,
serial rate, and wall time across worker counts `[1, 4, 8, 16, maxWorkers]`,
then computes the break-even N above which parallel beats serial.  
**Data required:** `S:\work\250Hz\Kerguelen2014\` wav folder.  
**Expected result:** Prints recommended `parallelThreshold` and produces a
worker-sweep plot. Run once after significant hardware changes. Last result
on SCI-001717 (31 workers): break-even = 62 slices.
