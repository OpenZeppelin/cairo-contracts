#!/usr/bin/env python
import shutil
from config import BUILD_DIRECTORY

def clean():
  shutil.rmtree(BUILD_DIRECTORY)

if __name__ == "__main__":
  clean()
