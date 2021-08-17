# Quakey

Quakey is a modern browser / manager / launcher for Quake 1 single player maps and mods, built on [Haxe](https://haxe.org/) + [Heaps](https://heaps.io/) + [HashLink](https://hashlink.haxe.org/) + [HaxeUI](http://haxeui.org/). "Netflix but for Quake mods."

- simple browsing interface that hooks into Quake archive [Quaddicted](https://www.quaddicted.com/); does all mod downloading, installing, and launching for you
- preconfigured to get you playing Quake in minutes
- Windows only (for now)

## Usage

1. Buy Quake and install it.
2. Download Quakey, and unzip ALL THE FILES somewhere on your computer, e.g. C:\Quakey\
    - NEW TO QUAKE? Get the "full" version, which includes preconfigured modern Quake single player engine [Quakespasm-Spiked](https://triptohell.info/moodles/qss/).
    - KNOW QUAKE ALREADY? Get the "minimal" version, which is just the Quakey program files.
3. Double-click on the unzipped Quakey.exe and follow the instructions.
    - It will try to find your retail Quake install and import the game data files. If it can't find the .pak files, you might have to help.
    - It can also apply recommended fixes and configs, inspired by [Quakestarter](https://github.com/neogeographica/quakestarter)

## Intent

[Quake Injector](https://github.com/hrehfeld/QuakeInjector) is a solid Quake mod browser tool, but (a) its Java dependency has aged poorly, (b) most of it was written in 2009?, and (c) the database-like interface assumes you already know what you like. It's not very newbie-friendly because it doesn't help Quake novices ease into Quake culture; there's no onboarding or discovery.

Quakey is basically a remake of Quake Injector but with more approachable curation and a visually-rich interface, geared toward an audience now familiar with online media app UX patterns like in Netflix. There's a simple queue system to track downloads, and then you click the play button. Additional options and features are easily accessible for power users too.

The tech stack (Haxe + Heaps + HashLink + HaxeUI) was chosen for ease of use and futureproofing. Haxe is very similar to common OOP languages, and Heaps and HaxeUI are mature and in active development as of 2021. A web frontend / Electron wrapper felt bloated and inappropriate.

## How to develop / build from source

1. install [Haxe](https://haxe.org/download/), [HashLink](https://hashlink.haxe.org/), [Git](https://git-scm.com/), and VS Code + the Haxe extension
2. install the needed Haxe libraries; for most of them, you should install the updated Git versions (NOT the outdated HaxeLib versions)
```
haxelib install hlsdl
haxelib git heaps https://github.com/HeapsIO/heaps.git
haxelib git haxeui-core https://github.com/haxeui/haxeui-core.git
haxelib git haxeui-heaps https://github.com/haxeui/haxeui-heaps.git
```
3. clone this repo and open the root folder in VS Code
4. make sure VS Code has regenerated the Haxe cache by restarting the Haxe language server (Ctrl + Shift + P >> Haxe: Restart Language Server)... you'll also need to do this anytime you edit the .xml files, since the Haxe macros need to regenerate all the Haxe UI code from the XML
5. in VS Code, select the heaps-hl.hxml target, and then press F5 to build and test in HashLink.
6. to build for release, use [redistHelper](https://github.com/deepnight/redistHelper).

## License

all Haxe source code in /src/ is licensed under GPL 3.0, in the tradition of Quake engines
