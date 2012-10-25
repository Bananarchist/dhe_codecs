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
            self.fileCount, self.fileDataOffset, self.fileNamesOffset, self.fileInfoOffset = unpack("<IIII", self.infile.read(16))
            self.fileInfo = []
            for i in xrange(self.fileCount):
                infile.seek(self.fileInfoOffset + (16 * i))
                self.fileInfo[i] = {}
                filenameOffset, self.fileInfo[i]["compressedSize"], self.fileInfo[i]["fileSize"], self.fileInfo[i]["fileOffset"] = unpack("<IIII", self.infile.read(16))
                self.infile.seek(filenameOffset)
                if self.fileInfo[i]["compressedSize"] != 0: self.fileInfo[i]["compressed"] = True
                else self.fileInfo[i]["compressed"] = False
                # if anyone knows how to read inderterminate length, null-terminated strings from a binary file better than this, please change it!
                # possible - read all the strings in one go and split the giant string at each \x00
                self.fileInfo[i]["fileName"] = ""
                self.longestFileName = 0
                l = 0
                c = self.infile.read(1)
                while c != '\x00':
                    self.fileInfo[i]["fileName"] = self.fileInfo[i]["fileName"] + c
                    l += 1
                    c = self.infile.read(1)
                if l > self.longestFileName: self.longestFileName = l
            self.outfile = None
        else: # make a DAR file
            try: self.outfile = open(kwargs.get("create"), "wb")
            except: pass
            self.infile = None
    def extractFiles(self, directory=None):
        """Extracts all files from DAR archive.

        Keyword Arguments:
        directory: the directory to output the files too. If it doesn't exist, it will be created. Defaults to the DAR file's name."""
        if not directory:
            directory = self.DARFileName
        try:
            os.mkdir(directory)
        except OSError:
            pass #probably because the directory exists already
        for i in xrange(self.fileCount):
            self.extractFile(i, 0, directory)
    def extractFile(self, fileindex, initialindex=0, directory=""):
        """Extracts the file at fileindex.

        Arguments:
        fileindex: the index of the particular file to extract.

        Keyword Arguments:
        initialindex: if not using zero indexing, pass the first index here. Defaults to zero.
        directory: where to save the extracted file. Defaults to current directory."""
        # does this default to the CWD or the directory in which the DAR is stored - experiments are necessary!
        fi = fileindex - initialindex
        self.infile.seek(self.fileInfo[fi]["fileOffset"])
        fn = os.path.join(directory, "%08X_%s" % (self.fileInfo[fi]["fileOffset"], self.fileInfo[fi]["fileName"]))
        ofile = open(fn, "wb")
        if self.fileInfo[fi]["compressed"]:
            try:
                data = zlib.decompress(self.infile.read(self.fileInfo[fi]["compressedSize"]))
            except:
                print "File at index %i (from initial index %i) failed to decompress despite appearing to be compressed. Outputting (compressed?) data to %s" % (fileindex, initialindex, fn)
                self.infile.seek(self.fileInfo[fi]["fileOffset"])
                data = self.infile.read(self.fileInfo[fi]["compressedSize"])
        else:
            data = self.infile.read(self.fileInfo[fi]["fileSize"])
        ofile.write(data)
        ofile.close()
    def addFile(self, *args, **kwargs):
        pass # DARS are probably the easiest to create with the least unknowns floating about them
    def info(self):
        """Formats a table of information on the DARFile

        Returns formatted string of DARFile information."""
        l = self.longestFileName - 8
        if l < 8: l = 8
        infostr = "DAR Container: \"%s\", %i files\nFile Data: %0#10X, File Descriptors: %0#10X, Filenames: %0#10X\n\n   Index\t%sFilename\tCompressed\tStored Size\t Full Size\t    Offset" % (self.DARFileName, self.fileCount, self.fileDataOffset, self.fileInfoOffset, self.fileNamesoffset, " " * l)
        for i in xrange(self.fileCount):
            file = self.fileInfo[i]
            if file["compressed"]: ss = file["compressedSize"]
            else: ss = file["fileSize"]
            infostr = ("%s\n%#8i\t%"+str(l+8)+"s\t%10s\t%0#10X\t %0#10X\t%0#10X") % (infostr, i, file["fileName"], file["compressed"], ss, file["fileSize"], file["fileOffset"])
        return infostr
    @staticmethod
    def isDARFile(infile):
        return False #for now



if __name__=="__main__":
    pass
