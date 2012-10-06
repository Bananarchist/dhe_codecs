import os, sys, zlib
from struct import *


class DAR_File:
    def __init__(self, *args, **kwargs):
        """Returns DAR_File object representing a DAR container file.

        Keyword Arguments:
        file: a file object created with the open command and "rb" (minimum) access.
        filename: a filename string pointing to a DAR file, unnecessary if infile is provided."""
        if "file" in kwargs.keys() or "filename" in kwargs.keys():
            try: self.infile = kwargs.get("file", open(kwargs["filename"], "rb"))
            except: 
                print "Failed to open file"
                exit()
            if not DAR_File.isDARFile(self.infile):
                pass # we need to throw some sort of error here
            self.DARFileName = self.infile.name.split(os.sep)[-1]
            self.infile.seek(0)
            self.fileCount, self.fileDataOffset, self.filenamesOffset, self.fileInfoOffset = unpack("<IIII", self.infile.read(16))
            self.fileInfo = []
            for i in xrange(self.fileCount):
                infile.seek(self.fileInfoOffset + (16 * i))
                self.fileInfo[i] = {}
                filenameOffset, self.fileInfo[i]["compressedSize"], self.fileInfo[i]["fileSize"], self.fileInfo[i]["fileOffset"] = unpack("<IIII", self.infile.read(16))
                self.infile.seek(filenameOffset)
                # if anyone knows how to read inderterminate length, null-terminated strings from a binary file better than this, please change it!
                # possible - read all the strings in one go and split the giant string at each \x00
                self.fileInfo[i]["fileName"] = ""
                c = self.infile.read(1)
                while c != '\x00':
                    self.fileInfo[i]["fileName"] = self.fileInfo[i]["fileName"] + c
                    c = self.infile.read(1)
            self.outfile = None
        else: # make a DAR file
            try: self.outfile = open(kwargs.get("create"), "wb")
            except: pass
            self.infile = None
    def extractFiles(self):
        pass
    def extractFile(self, fileindex, initialindex=None):
        pass
    def addFile(self, *args, **kwargs):
        pass # DARS are probably the easiest to create with the least unknowns floating about them
    def info(self):
        pass
    @staticmethod
    def isDARFile(infile):
        return False #for now



if __name__=="__main__":
    pass
