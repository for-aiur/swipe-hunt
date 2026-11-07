# Swipe Hunt

<p align="center">
  <strong>One room. One runner. Catch it before it escapes.</strong><br>
  A mobile-first, pixel-art dungeon chase built with Godot 4.
</p>

<p align="center">
  <a href="https://swipe-hunt-playtest.pages.dev"><strong>Play in your browser →</strong></a>
</p>

<p align="center">
  <a href="https://github.com/for-aiur/swipe-hunt/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/for-aiur/swipe-hunt?style=flat"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
  <img alt="Godot 4" src="https://img.shields.io/badge/Godot-4-478CBF?logo=godot-engine&logoColor=white">
  <a href="https://swipe-hunt-playtest.pages.dev"><img alt="Browser demo" src="https://img.shields.io/website?url=https%3A%2F%2Fswipe-hunt-playtest.pages.dev&label=Browser%20demo"></a>
  <img alt="Platforms: Web and Android" src="https://img.shields.io/badge/Platforms-Web%20%7C%20Android-6c5ce7">
</p>

Swipe through a dark, hand-built dungeon, follow fading footprints, and strike
the fleeing creature before it reaches an exit. Each round is short, readable,
and ready to replay.

## Play

Open the [browser demo](https://swipe-hunt-playtest.pages.dev) on desktop or
mobile. No account or download is needed.

## Controls

| Action | Touch | Desktop |
| --- | --- | --- |
| Move | Swipe | Arrow keys or WASD |
| Attack | Tap | Click, Space, or Enter |

Only the current room is shown. A hit catches the creature in one strike; there
are no health bars or combat menus. Running into a wall briefly stuns the
hunter.

## Run locally

1. Install [Godot 4.2 or newer](https://godotengine.org/download/).
2. Clone this repository and open `project.godot` in Godot.
3. Press **F5** to play.

The project uses code-drawn pixel art and has no external runtime services.

## Build for the web

Install the export template matching your Godot version and the Brotli CLI, then
run:

```sh
./scripts/export_web.sh
```

This creates a Cloudflare Pages-ready build in `build/web/`.

## Contributing

Bug reports and focused pull requests are welcome. Include your Godot version,
platform, and steps to reproduce when reporting a problem. See
[AGENTS.md](AGENTS.md) for project structure and contribution guidance.

## License

Swipe Hunt is released under the [MIT License](LICENSE).
