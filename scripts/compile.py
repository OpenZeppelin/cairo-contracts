#!/usr/bin/env python
import sys, os, subprocess
from config import CONTRACTS_DIRECTORY, BUILD_DIRECTORY, ABIS_DIRECTORY

def compile(path):
  base = os.path.basename(path)
  filename = os.path.splitext(base)[0]
  print("🔨 Compiling {}".format(path))

  cmd = """
  starknet-compile {path} \
    --output {BUILD_DIRECTORY}{filename}.json \
    --abi {ABIS_DIRECTORY}{filename}.json
  """.format(
    path=path,
    BUILD_DIRECTORY=BUILD_DIRECTORY,
    ABIS_DIRECTORY=ABIS_DIRECTORY,
    filename=filename)

  process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
  output, error = process.communicate()


def get_all_contracts():
  for filename in os.listdir(CONTRACTS_DIRECTORY):
    if filename.endswith(".cairo"):
        yield os.path.join(CONTRACTS_DIRECTORY, filename)


if __name__ == "__main__":
  if not os.path.exists(ABIS_DIRECTORY):
    print("Creating {} to store compilation artifacts".format(ABIS_DIRECTORY))
    os.makedirs(ABIS_DIRECTORY, exist_ok=True)
  
  params = sys.argv

  if len(params) == 1:
    print("🤖 Compiling all Cairo contracts in the {} directory".format(CONTRACTS_DIRECTORY))
    for path in get_all_contracts():
      compile(path)
  elif len(params) == 2:
    compile(params[1])
  else:
    for path in params[1:]:
      compile(path)
