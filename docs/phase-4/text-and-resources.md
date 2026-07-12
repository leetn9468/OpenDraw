# Text and raster resource subsystem

Point text stores Unicode content, requested font name, size, sRGB color, origin and
affine transform. `TextEngine` owns Core Text shaping/drawing. Missing system fonts
use Core Text fallback without replacing the requested stored name. Area text,
paragraph layout and text-on-path are not represented yet.

Raster objects store a document-space frame, declared pixel size and either embedded
bytes or a relative linked path. The loader caps encoded input at 50 MiB and decoded
dimensions at 50 megapixels. Absolute and parent-traversal links are rejected.
Embedded bytes are decoded through ImageIO; missing/invalid resources render an
original crossed placeholder without making the document invalid.

Large-image thumbnails, bookmark-based sandbox access, color-profile conversion and
relink UI are future capabilities. Linked paths are data only: rendering does not
implicitly access disk or network resources.
