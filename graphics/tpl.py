import os, sys
from struct import *


class TPL_DBlock:
    """How to read the image data into discrete blocks for constructing images"""
    def __init__(self, block):
        self.hShift, self.vShift, self.readStart, self.hrle, self.vrle = block[0], block[1] >> 1, block[2], block[3], block[4] >> 2
# No other methodss necessary?

class TPL_CBlock:
    """How to read the DBlock data into discrete images"""
    def __init__(self, data):
        pass
        

class TPL_File:
    def __init__(self, infile):
        pass
    def extractFile(self, fileIndex = 0, targetDir = None, fileName = None):
        pass
    def extractAll(self, targetDir = None):
        pass
    def info(self):
        pass
    def isTPL(infile):
        pass



if __name__=="__main__":
    pass
