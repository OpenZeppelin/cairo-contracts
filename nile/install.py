#!/usr/bin/env python
import sys, os, shutil, subprocess
import urllib.request
from config import TEMP_DIRECTORY

def install(tag):
  url = "https://github.com/starkware-libs/cairo-lang/releases/download/v{}/cairo-lang-{}.zip".format(tag, tag)
  location = "{}cairo-lang-{}.zip".format(TEMP_DIRECTORY, tag)
  os.makedirs(TEMP_DIRECTORY, exist_ok=True)
  urllib.request.urlretrieve(url, location)
  subprocess.check_call([sys.executable, "-m", "pip", "install", location])
  shutil.rmtree(TEMP_DIRECTORY)

if __name__ == "__main__":
  if len(sys.argv) == 2:
    install(sys.argv[1])
  else:
    print("Please provide a valid Cairo language version. For example:")
    print("")
    print("nile install 0.4.0")
    print("")
