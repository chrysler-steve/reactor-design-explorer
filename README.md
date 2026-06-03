# Reactor Design Explorer

An interactive MATLAB application for simulating and comparing chemical reactor designs. Built as a final-year chemical engineering showcase project.

## Features

- **Three reactor types**: Batch, CSTR (Continuous Stirred Tank Reactor), and PFR (Plug Flow Reactor)
- **Live parameter control**: Adjust temperature, flow rate, concentration, activation energy, and reaction order in real time
- **3D animations**: Animated 3D visualisations of each reactor with particle flow
- **Side-by-side comparison**: Overlay all three reactors on shared axes to compare conversion and concentration profiles
- **Dark-themed GUI**: Professional multi-window interface built entirely in MATLAB

## Running the App

### Option 1 — Installer (no MATLAB needed)
1. Download `installer/ReactorDesignExplorer_Setup.exe`
2. Run the installer — it will download and install MATLAB Runtime R2024a automatically (internet required, one-time ~800 MB)
3. Launch **Reactor Design Explorer** from the Start Menu or desktop shortcut

### Option 2 — MATLAB source (requires MATLAB R2024a)
```matlab
cd('path\to\this\folder')
ReactorDesignExplorer
```

### Reload command (after editing source files)
```matlab
close all force; clear classes;
cd('path\to\this\folder');
ReactorDesignExplorer;
```

## File Structure

| File | Purpose |
|------|---------|
| `ReactorDesignExplorer.m` | Main hub — reaction setup panel and reactor launcher |
| `BatchReactorWindow.m` | Batch reactor window with 3D animation |
| `CSTRWindow.m` | CSTR window with 3D animation |
| `PFRWindow.m` | PFR (shell-and-tube) window with 3D animation |
| `ReactorCompareWindow.m` | Comparison overlay — all three reactors on shared axes |
| `rxKinetics.m` | Kinetics engine — Arrhenius, analytical Ca solutions for all reactor types |
| `rxWindowStyle.m` | Shared UI styling helpers |
| `compileApp.m` | Script to recompile the standalone exe (requires MATLAB Compiler) |
| `buildInstaller.m` | Script to rebuild the installer package (requires MATLAB Compiler) |

## Reactor Physics

Supports **first-order** and **second-order** reactions with user-configurable parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| C₀ | 0.1 mol/L | Initial concentration |
| Eₐ | 43790 J/mol | Activation energy |
| A | 1.11×10⁸ | Pre-exponential factor |
| Vᵣ | 1.0 L | Reactor volume |
| tₘₐₓ | 20 min | Batch time horizon |

Analytical solutions (Arrhenius rate constant k = A·exp(−Eₐ/RT)):

| Reactor | 1st order | 2nd order |
|---------|-----------|-----------|
| Batch | Cₐ = C₀·exp(−k·t) | Cₐ = C₀/(1 + k·C₀·t) |
| CSTR | Cₐ = C₀/(1 + k·τ) | Cₐ = 2C₀/(1 + √(1 + 4k·τ·C₀)) |
| PFR | Cₐ = C₀·exp(−k·V/q) | Cₐ = C₀/(1 + k·C₀·V/q) |

## Requirements

- MATLAB R2024a (for source files)
- Or MATLAB Runtime R2024a (for the compiled installer — free from MathWorks)
- No additional toolboxes required

## Author

Chrysler Steve — Chemical Engineering, Final Year
