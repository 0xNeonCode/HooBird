# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""EXIF is removed before encryption. The server never sees the plaintext image."""

import io

import piexif
from PIL import Image

from media_prep import strip_jpeg


def test_strip_jpeg_drops_gps_and_description():
    image = Image.new("RGB", (16, 16), (20, 140, 60))
    output = io.BytesIO()
    exif = {
        "0th": {piexif.ImageIFD.ImageDescription: b"GPSLAT-48.12345"},
        "GPS": {
            piexif.GPSIFD.GPSLatitudeRef: b"N",
            piexif.GPSIFD.GPSLatitude: ((48, 1), (12, 1), (0, 1)),
        },
    }
    image.save(output, format="JPEG", exif=piexif.dump(exif))
    original = output.getvalue()
    assert b"GPSLAT-48.12345" in original
    assert piexif.load(original)["GPS"]

    stripped = strip_jpeg(original)
    assert b"GPSLAT-48.12345" not in stripped
    assert stripped.startswith(b"\xff\xd8\xff")
    assert not piexif.load(stripped).get("GPS")
