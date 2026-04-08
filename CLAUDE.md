# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Video poker game built with Godot 4.6 (Forward Plus renderer, Jolt Physics). GDScript is the primary language.

## Engine & Tooling

- **Godot version:** 4.6
- **Open project:** `open "/Users/vadimprokop/Documents/Godot/video poker/project.godot"` or launch from Godot project manager
- **Run from CLI:** `/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/vadimprokop/Documents/Godot/video poker"`
- **Project config:** `project.godot` — edited via Godot editor UI, not manually

## Architecture

This is currently a fresh project scaffold. As development proceeds:

- Scenes (`.tscn`) define the node tree and UI layout
- Scripts (`.gd`) attach to scene nodes for game logic
- Resources (`.tres`) store data like card definitions or payout tables
- The `.godot/` directory is auto-generated and gitignored

## Conventions

- GDScript files use `snake_case` for variables/functions, `PascalCase` for classes/nodes
- Scene files pair with same-named scripts (e.g., `main.tscn` + `main.gd`)
- Charset is UTF-8 (see `.editorconfig`)
- Project name is in Russian ("Новый игровой проект") — may be renamed later
