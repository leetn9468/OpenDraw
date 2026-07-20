# U3-B final command reachability audit

U3-A's retired 27-item text strip still has no exclusive commands. U3-B adds
the five formerly disabled align-family destinations and removes no reachable
capability.

| Command family | Reachable from |
|---|---|
| New, Open, Save, Export | File menu and native toolbar |
| Undo, Redo | Edit menu |
| Select, Direct Select, Pen, Rectangle, Ellipse, Text, Image | Tools menu and tool rail |
| Style, Properties, Gradient | Object menu and Inspector |
| Zoom Out, Actual Size, Zoom In | View menu and toolbar zoom cluster |
| Zoom Fit | View menu and native toolbar |
| Align Left, Center, Right, Top, Middle, Bottom | Object menu and Inspector; all enabled |
| Group, Ungroup, Make Compound, Release Compound | Object menu and Inspector |
| Layers | View menu and native toolbar toggle |
| Inspector | View menu and native toolbar toggle |
| Snap | View menu |

Open continues to accept native and SVG documents; the File menu names the SVG
route as `Import SVG...`. Export remains SVG because no PNG capability was
invented. The superseded Create Text alert has no menu command of its own: the
Text tool now enters the in-place editor directly.

Final result: every pre-redesign command remains reachable and all six align
commands are live. No menu exception remains open at U3-B closure.
