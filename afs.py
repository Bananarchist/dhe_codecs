import os, sys
from struct import *


class AFS_File:
    def __init__(self, infile):
        self.AFSFileName = infile.name
        infile.seek(0)
        identifier, self.fileCount = unpack("<II", infile.read(8))
        if identifier != 0x41465300:
            print "This doesn't seem to be an AFS file"
            exit()
        self.fileInfo = []
        # get each file's offset and size
        for i in xrange(self.fileCount):
            self.fileInfo.append({})
            self.fileInfo[i]["dataOffset"], self.fileInfo[i]["dataRunLength"] = unpack("<II", infile.read(8))
        fileNamesOffset, fileNamesRunLength = unpack("<II", infile.read(8))
        infile.seek(fileNamesOffset)
        for i in xrange(self.fileCount):
            self.fileInfo[i]["fileName"] = infile.read(32).strip("\0")
            self.fileInfo[i]["u"] = unpack("<IIII", infile.read(16))
        self.infile = infile
    def extractFiles(self, outputdirectory=os.getcwd(), extrainfo=False):
        """Extracts all files within to outputdirectory.
        
        outputdirectory: If it contains a path separator, it will be interpreted as an absolute path
        extrainfo: prints out status while processing file"""
        # %(do)08x_%(fn)s
        for file in self.fileInfo:
            fn = "%08x_%s", (file["dataRunLength"], file["fileName"])
            
        pass
    def info(self):
        """Prints out info about the AFS file and contained files"""
        infostr = "AFS Container \"%s\", %i files\n\n                        Filename\t      Size\t    Offset\t        U1\t        U2\t        U3\t        U4" % (self.AFSFileName, sekf.fileCount)
        for file in self.fileInfo:
            infostr = "%s\n%32s\t%#10i\t%0#10x\t%0#10x\t%0#10x\t%0#10x\t%0#10x" % (infostr, file["fileName"], file["dataRunlength"], file["dataOffset"], file["u"][0], file["u"][1], file["u"][2], file["u"][3])
        print infostr
    def isAFSFile(infile):
        """Class method for detecting if the infile is an AFS file or byte list"""
        identifier = 0
        if type(infile) == list:
            identifier = (infile[0] << 24) | (infile[1] << 16) | (infile[2] << 8) | (infile[3])
        elif type(infile) == file:
            identifier = unpack("<I", infile.read(4))
        if identifier == 0x41465300:
            return True
        return False


if __name__=="__main__":
    pass
