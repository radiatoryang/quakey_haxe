# Quakey

Quakey is a modern browser / manager / launcher for Quake 1 single player maps and mods, built on Haxe + Heaps + HashLink + HaxeUI.

- simple Netflix-like browsing interface
- handles all mod downloading, installing, and launching
- preconfigured to get you playing Quake in minutes
- Windows only (for now)

## Usage

1. Buy Quake and install it.
2. Download Quakey from the Release page, and unzip ALL THE FILES somewhere on your computer.
- NEW TO QUAKE? Get the "full" version, which includes a preconfigured modern Quake engine Quakespasm-Spiked.
- KNOW QUAKE ALREADY? Get the "minimal" version, which is just the Quakey program files.
3. Double-click on the unzipped Quakey.exe and follow the setup instructions.

## How to develop / build from source

1. install Haxe, HashLink, HaxeLib, Git, and VS Code + the Haxe extension
2. install the needed Haxe libraries; for most, you should install the updated Git versions (NOT the outdated HaxeLib versions)
```
haxelib install hlsdl
haxelib git heaps (url)
haxelib git haxeui-core (url)
haxelib git haxeui-heaps (url)
```
3. clone this repo and open the root folder in VS Code
4. make sure VS Code has regenerated the Haxe cache by restarting the Haxe language server (Ctrl + Shift + P >> Haxe: Restart Language Server)... you'll also need to do this anytime you edit the .xml files, since the Haxe macros need to regenerate all the Haxe UI code from the XML
5. select the heaps-hl.hxml target, and then press F5 to build and test in HashLink.
6. to build for release, use redistHelper.

## Intent

Quake Injector is a solid Quake mod browser tool, but (a) its Java dependency has aged poorly, (b) most of it was written in 2009?, and (c) the database-like interface assumes you already know what you like. It's not very newbie-friendly because it doesn't help Quake novices ease into Quake culture; there's no onboarding or discovery.

Quakey is basically a remake of Quake Injector but with more approachable curation and a visually-rich interface, geared toward an audience now familiar with online media app UX patterns. There's a simple queue system to track downloads, and then you click the play button. Additional options and features are easily accessible for power users too.

The tech stack (Haxe + Heaps + HashLink + HaxeUI) was chosen for ease of use and futureproofing. Haxe is very similar to common OOP languages, and Heaps and HaxeUI are mature and in active development as of 2021. A web frontend / Electron wrapper felt bloated and inappropriate.

## License

GPL, in the tradition of Quake engines