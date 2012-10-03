import os, sys
from struct import *


class AFS_File:
    """Class representing an AFS container file object."""
    def __init__(self, infile):
        """Takes file object, returns AFS_File object.

        infile: file object, usually obtained via open command. Must be at least "rb" mode"""
        self.AFSFileName = infile.name.split(os.sep)[-1]
        if not AFS_File.isAFSFile(infile):
            pass #we need to throw some sort of agreed upon error here
        infile.seek(4)
        self.fileCount = unpack("<I", infile.read(4))[0]
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
        
        outputdirectory: if not provided, will create new folder in current working directory
        extrainfo: prints out status while processing file"""
        if outputdirectory == os.getcwd(): outputdirectory = self.AFSFileName.split(".")[0] + "_files"
        try: os.mkdir(outputdirectory)
        except: pass # chances are it failed because it exists and we tried creating it
        for file in self.fileInfo:
            self.infile.seek(file["dataOffset"])
            fn = "%08X_%s" % (file["dataOffset"], file["fileName"])
            with open(os.path.join(outputdirectory, fn), "wb") as oot:
                data = self.infile.read(file["dataRunLength"])
                oot.write(data)
                if extrainfo:
                    print "Outputting %s as %s to %s" % (file["fileName"], fn, outputdirectory) 
    def info(self):
        """Prints out info about the AFS file and contained files"""
        infostr = "AFS Container \"%s\", %i files\n\n                        Filename\t      Size\t    Offset\t        U1\t        U2\t        U3\t        U4" % (self.AFSFileName, self.fileCount)
        for file in self.fileInfo:
            infostr = "%s\n%32s\t%#10i\t%0#10X\t%0#10X\t%0#10X\t%0#10X\t%0#10X" % (infostr, file["fileName"], file["dataRunLength"], file["dataOffset"], file["u"][0], file["u"][1], file["u"][2], file["u"][3])
        print infostr
    @staticmethod
    def isAFSFile(infile):
        """Class method for detecting if infile is an AFS file"""
        infile.seek(0)
        identifier = unpack("BBBB", infile.read(4))
        if identifier == (0x41, 0x46, 0x53, 0x00):
            return True
        return False


if __name__=="__main__":
    usage = "Usage: [python] %s [mode] [options] inputfile\n\nCommands:\n\tE, e: default beahvior, extracts all files in AFS\n\tI, i: print information and exit\n\tO, o: output files to specific directory (o directory)\n\tV, v: output extra information, only meaningful in extract mode (using e flag)\n" % sys.argv[0]
    if len(sys.argv) < 2:
        print usage
        exit
