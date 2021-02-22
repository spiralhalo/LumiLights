# Lumi Lights 
A shader pack for Canvas with PBR Forward Rendering Demo.

### Features list
- Bluish ambiance during the day in the overworld, purplish in the End, and fog-colored in the nether.
- Brighter sun with directional light.
- Clearer and shinier water.
- Bloom on the sky.

### PBR Demo features list
- Bump generation
- Roughness / Metallic material params

## Using

- [Download version 1.0.1267 of Canvas.](https://github.com/grondag/canvas/releases/tag/1.0.1267-unstable)
  - To use with latest version of Canvas, you need to use (unreleased) WIP version of Lumi Lights. Join the discord for instructions (link below) as any information released here will not always be up-to-date.
- [Download the latest **unified** release of Lumi Lights.](https://github.com/spiralhalo/LumiLightsPBR/releases) If you have [Respackopts](https://modrinth.com/mod/TiF5QWZY/) installed you may use the **respackopts** edition instead.
- Put Lumi Lights inside your resource pack folder.

\*Please [open an issue](https://github.com/spiralhalo/LumiLightsPBR/issues) if Lumi Lights does not work with the latest version of Canvas.

## PBR Packs

- [Lumi PBR Ext](https://github.com/spiralhalo/LumiPBRExt) adds vanilla PBR materials.
- [Lumi PBR Compat](https://github.com/spiralhalo/LumiPBRCompat) adds PBR materials for third party modded objects.

**PBR packs requires PBR shading mode.** PBR shading mode is enabled by default and requires higher performance machine. See instructions below to enable or disable PBR shading mode.

## Configuring

- To personalize your installation of Lumi Lights, extract it into a `Lumi Lights` folder inside your resource pack folder.
- Open the `Lumi Lights` folder and navigate to `/assets/lumi/`. Open `config.glsl` in a text editor.
- To disable PBR shading mode, simply remove the line `#define LUMI_PBR`. Readd that line to re-enable it.
- Other configuration options are version dependent and instructions to configure them are included within the config file.

\*If you have [Respackopts](https://modrinth.com/mod/TiF5QWZY/) installed you may use the **respackopts** edition (available in all releases since v0.5) which comes with a config screen that lets you change the configurations on the fly.

## License

Lumi Lights is released **without any warranty** under the GNU Lesser General Public License version 3 as published by the Free Software Foundation. See the files `COPYING` and `COPYING.LESSER` for license terms. You may also obtain a copy of the license at https://www.gnu.org/licenses/lgpl-3.0.html.

Have some questions? [Join the Lumi Lights discord.](https://discord.gg/qcyBfhxkgk)
