# pamLtsa

MATLAB tools for working with long-term passive acoustic recordings from
the Australian Antarctic Division's moored acoustic recorders (MARs),
deployed at Antarctic and sub-Antarctic sites since 2002.

---

## Overview

The primary workflow this repository supports is quality control (QC) of
MAR data after return-to-Australia (RTA). The first step in that process
is computing a long-term spectral average (LTSA) — a time-frequency
representation of the recording that makes data gaps, instrument noise,
and biological signals immediately visible.

Beyond QC, the repository has grown to include tools for deployment
metadata management, calibrated LTSA plotting, spectral probability
distributions, recording effort analysis, and data gap visualisation.

---

## Key functions

### LTSA computation
| Function | Description |
|----------|-------------|
| `wavFolderToLtsa` | Compute LTSA from a folder of wav files. Supports parallel processing, click suppression, and incremental saving. |

### LTSA loading and calibration
| Function | Description |
|----------|-------------|
| `loadLtsa` | Load a saved LTSA `.mat` file with optional time subsetting. |
| `calibrateLtsa` | Apply hydrophone calibration to raw PSD arrays (returns dB re 1 µPa²/Hz). |
| `attachLtsa` | Calibrate and attach LTSA arrays to a metadata struct, producing the standard struct shape used throughout the repo. |
| `loadCalibratedLtsa` | Convenience wrapper: loads LTSA from disk and applies calibration. Accepts a site code string or metadata struct. |

### Plotting
| Function | Description |
|----------|-------------|
| `plotCalibratedLtsa` | Plot a calibrated LTSA on log-frequency axes. Accepts an axes handle for use in tiledlayout. |
| `plotSpd` | Plot spectral probability distribution from an LTSA. |
| `ltsaToSpd` | Compute and plot SPD by season or month from an LTSA struct. |
| `plotDataGaps` | Shade data gaps on the current axes. |
| `plotDeploymentLocations` | Plot MAR deployment locations on a UTM map (requires m_map). |

### Metadata
| Function | Description |
|----------|-------------|
| `loadRecorderMetaData` | Load deployment metadata by site code (e.g. `'kerguelen2014'`). Supports individual sites and group codes (`'casey'`, `'kerguelen'`, `'kombi'`, etc.). |
| `metaDataSiteYear` | Per-deployment metadata functions (e.g. `metaDataKerguelen2014`). One file per deployment. |

### Recording effort and gaps
| Function | Description |
|----------|-------------|
| `getRecordingEffort` | Compute recording effort in hours, binned by year, season, month, week, or day. Works with both wav and xwav folders. |
| `getNoDataTimes` | Find time periods with no data across one or more deployments, based on actual wav file start/end times. |

### Utilities
| Function | Description |
|----------|-------------|
| `wavFileNameToDatetime` | Parse timestamps from PAMGuard selection table filenames. Handles multiple AAD recorder naming conventions. |
| `loadLtsa` | Load LTSA from disk with time subsetting and off-by-one guard. |

### Scripts
| Script | Description |
|--------|-------------|
| `ltsaSiteYear.m` | One script per deployment (e.g. `ltsaKerguelen2014_3600s_1Hz.m`). Calls `wavFolderToLtsa` with deployment-specific parameters. |
| `checkForRecordingGaps.m` | Example script showing how to detect and plot gaps for a single deployment. |
| `wavFolderInfo_AAD_250Hz.m` | Script to run `wavFolderInfo` across all 250 Hz downsampled AAD recordings. |

---

## Dependencies

- [soundFolder](https://github.com/BrianSMiller/soundFolder) —
  `wavFolderInfo`, `getAudioFromFiles`, `xwavFolderInfo`
- bsmTools (private) —
  `removeClicks`, `dn2dt`, `season`, `plotSquare`. These are candidates
  for migration into this repo or other public packages to remove the
  private dependency.
- [m_map](https://www.eoas.ubc.ca/~rich/map.html) —
  required by `plotDeploymentLocations` only
- MATLAB Parallel Computing Toolbox (optional — for `parallel=true` in
  `wavFolderToLtsa`)

---

## Getting started

```matlab
% Add dependencies to path
addpath('c:\analysis\soundFolder\');
addpath('c:\analysis\bsmUtils\');
addpath('c:\analysis\pamLtsa\');

% Build file index for a wav folder
fileInfo = wavFolderInfo('S:\work\250Hz\Kerguelen2014\');

% Compute a 1-hour LTSA for a deployment
startTime = datenum(2014, 4, 1, 0, 0, 0);
endTime   = datenum(2014, 10, 1, 0, 0, 0);
wavFolderToLtsa('ltsa\kerguelen2014_3600s_1Hz.mat', fileInfo, startTime, endTime);

% Load, calibrate, and plot
data = loadCalibratedLtsa('kerguelen2014');
plotCalibratedLtsa(data);
```

---

## Deployment sites

Sites with metadata functions and LTSAs include Casey, Kerguelen,
Prydz Bay, DDU, KOMBI (Four Ladies Bank), MEEK, Heard Island, and Scott Base.
Deployments span 2002 to present. Authoritative deployment metadata is
stored in a SQLite database; the `metaDataSiteYear.m` functions are
a MATLAB-compatible subset of that record.

---

## Notes

- Wav file timestamp formats vary by recorder and software version.
  `wavFolderInfo` handles the common AAD formats automatically; pass
  an explicit format string for non-standard layouts.
- LTSAs are saved as `.mat` files (v7.3) containing `t`, `freqs`, `ltsa`,
  and `errorLog`. Load with `loadLtsa` or `loadCalibratedLtsa`.
- Early deployments (Casey 2004, Kerguelen 2005/2006, Prydz 2005/2006)
  used ARP recorders with xwav format files; these require `xwavFolderInfo`
  rather than `wavFolderInfo`.
- The `legacy/` folder contains pre-refactor versions of `wavFolderToLtsa`
  and related scripts. These are not on the MATLAB path and should not be
  used for new work.

---

## Design philosophy and relationship to other tools

This repository follows a loosely coupled, Unix-philosophy approach: small
functions that do one thing well, composable into pipelines, with explicit
dependencies. This contrasts with monolithic tools like
[MANTA](https://www.frontiersin.org/articles/10.3389/fmars.2021.703650)
(Ocean Sound Analysis Software for Making Ambient Noise Trends Accessible),
which owns the full stack from raw audio to archived NetCDF.

**Relationship to MANTA and the HMD standard:**
`ltsaToMillidecade` produces output in the hybrid millidecade (HMD) band
format of [Martin et al. (2021)](https://doi.org/10.1121/10.0003324),
which is the same format used by MANTA. The outputs are therefore directly
comparable to MANTA-processed data from other institutions. The key
differences are temporal resolution (hourly vs MANTA's 1-minute default)
and output format (.mat vs NetCDF/CSV). NetCDF output and
[PassivePacker](https://www.ncei.noaa.gov/products/passive-acoustic-data)
metadata packaging for submission to NCEI are not currently implemented.

**Why loosely coupled:**
The AAD passive acoustic monitoring program spans a wide range of instruments
(ARPs, MARs, ALTOs, SonoVaults), duty cycles, sample rates, and species of
interest. A loosely coupled design makes it straightforward to adapt
individual components — processing parameters, calibration, detection
pipelines — without touching the rest of the stack. This is particularly
important for non-standard deployments such as multi-channel or
mixed-sample-rate recorders.

**Relationship to Tethys and ASA S3/SC1.7:**
[Tethys](https://tethys.sdsu.edu) is the community standard database schema
for passive acoustic metadata, and forms the basis of NOAA NCEI's passive
acoustic archive. The ASA/ANSI S3/SC1.7 standard specifies what metadata
should be retained for PAM deployments. This repository's
`metaDataSiteYear.m` functions contain the relevant deployment metadata
fields but are not yet packaged in a Tethys- or S3/SC1.7-compatible format.
Integration with these standards is a future goal.
