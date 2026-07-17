import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


BENCHMARK_SCRIPT = Path(__file__).with_name("benchmark.py")


class BenchmarkCliTest(unittest.TestCase):
    def test_json_output_fails_when_an_artifact_cannot_be_processed(self):
        with tempfile.TemporaryDirectory() as target_dir:
            artifact = Path(target_dir) / "openzeppelin_Invalid.compiled_contract_class.json"
            artifact.write_text("not valid json", encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    str(BENCHMARK_SCRIPT),
                    "--json",
                    "--dir",
                    target_dir,
                ],
                check=False,
                capture_output=True,
                text=True,
            )

            output = json.loads(result.stdout)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("error", output["bytecode"][artifact.name])
            self.assertIn(artifact.name, result.stderr)


if __name__ == "__main__":
    unittest.main()
