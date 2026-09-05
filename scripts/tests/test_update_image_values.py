"""Exercise promotion validation and failure recovery without cloud credentials."""

import argparse
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "update-image-values.py"
spec = importlib.util.spec_from_file_location("promotion", SCRIPT)
promotion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(promotion)


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.args = argparse.Namespace(
            root=self.root, environment="local", repository="ghcr.io/example/demo",
            digest="sha256:" + "a" * 64, version="1.0", git_sha="1234567",
            check_digest=None,
        )
        self.destination = self.root / "platform/environments/local/image-values.yaml"

    def run_promotion(self):
        with patch.object(promotion, "parse_args", return_value=self.args):
            promotion.main()

    def test_metadata_remains_a_string_for_yaml_ambiguous_versions(self):
        for version in ["1.0", "null", "true", "0123", "1e3"]:
            self.args.version = version
            self.run_promotion()
            self.assertIn(f"  version: {json.dumps(version)}\n", self.destination.read_text())

    def test_failed_replace_preserves_previous_file_and_cleans_temporary(self):
        self.run_promotion()
        original = self.destination.read_bytes()
        self.args.version = "2.0"
        with patch.object(Path, "replace", side_effect=OSError("synthetic disk failure")):
            with self.assertRaises(OSError):
                self.run_promotion()
        self.assertEqual(self.destination.read_bytes(), original)
        self.assertEqual(list(self.destination.parent.iterdir()), [self.destination])

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            (self.root / "platform").symlink_to(outside, target_is_directory=True)
            with self.assertRaises(SystemExit):
                self.run_promotion()
            self.assertEqual(list(Path(outside).iterdir()), [])

    def test_invalid_digest_and_metadata_are_rejected(self):
        for value in ["latest", "sha256:abc", "sha256:" + "G" * 64, "sha256:" + "a" * 64 + "\n"]:
            with self.assertRaises(argparse.ArgumentTypeError):
                promotion.validated_digest(value)
        for value in ["a\nb", "x: y", ""]:
            with self.assertRaises(argparse.ArgumentTypeError):
                promotion.validated_text(value)


if __name__ == "__main__":
    unittest.main()
