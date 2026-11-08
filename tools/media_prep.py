# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Client-side image preparation used by the generic-client fixture tests.

The server cannot strip EXIF inside Megolm ciphertext. Callers must run this
before encryption. Re-encoding with Pillow drops EXIF, GPS and JPEG comments.
"""

from __future__ import annotations

import io

from PIL import Image


def strip_jpeg(data: bytes) -> bytes:
    image = Image.open(io.BytesIO(data))
    rgb = image.convert("RGB")
    output = io.BytesIO()
    rgb.save(output, format="JPEG", quality=85)
    return output.getvalue()
