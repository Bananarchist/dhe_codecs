import sys, os, zlib
from struct import *


cwd = os.getcwd()
verbose = False


class GMP_File:
	def __init__(self, infile):
		"""Class representing the GMP archive format."""
		self.GMPFileName = infile.name #######
		infile.seek(0)
		self.fileCount, self.descriptorOffset, self.unknown0, self.unknown1 = unpack("<IIII", infile.read(16))
		self.fileDescriptors = []
		for i in xrange(self.fileCount):
			infile.seek(self.descriptorOffset + i * 32)
			self.fileDescriptors.append({});
			self.fileDescriptors[i]["name"] = infile.read(20).strip("\0") #guarding against null file names
			if(len(self.fileDescriptors[i]["name"]) == 0):
				self.fileDescriptors[i]["name"] = "f" + str(i)
			self.fileDescriptors[i]["rl"], self.fileDescriptors[i]["offset"], self.fileDescriptors[i]["unknown"] = unpack("<III", infile.read(12))
		self.infile = infile
	def extractFiles(self):
		"""Extract all files contained within the GMP file to the current working directory (obtained by os.getcwd())."""
		if self.infile.closed:
			try:
				self.infile = open(self.GMPFileName)
			except IOError:
				print self.GMPFileName + " was closed, and we couldn't reopen it. Quitting..."
				exit()
		try: 
			os.mkdir(self.GMPFileName + "_files")
		except:
			pass
		for i in xrange(self.fileCount):
			self.infile.seek(self.fileDescriptors[i]["offset"])
			filedata = self.infile.read(self.fileDescriptors[i]["rl"])
			if verbose:
				print "Writing file %(name)s (unknown descriptor: %(unknown)08x)" % self.fileDescriptors[i]
			with open((self.GMPFileName + "_files/" + self.fileDescriptors[i]["name"]).encode(), "wb") as oot:
				oot.write(filedata)
	def info(self):
		"""Return a string containing information on the file represented by this object."""
		str = "Files: %d\tDescriptor offset: %08x\tUnknown 1: %08x\tUknown 2: %08x\n\n%20s\t%8s\t%8s\n" % (self.fileCount, self.descriptorOffset, self.unknown0, self.unknown1, "Filename", "Size", "Offset")
		for i in xrange(self.fileCount):
			str += "%(name)20s\t%(rl)08x\t%(offset)08x\n" % self.fileDescriptors[i]
		return str + "\n"



			
if __name__=="__main__":
	if len(sys.argv) < 2:
		print "Usage:\t" + sys.argv[0] + " gmpfile [V|v] \n\nOptions: \n\tV, v: verbose, output some extra information"
		exit()
	else:
		try:
			infile = open(sys.argv[1], "rb")
		except: 
			"We were unable to open the file " + sys.argv[1]
			exit()
		if len(sys.argv) > 2:
			if sys.argv[2] == "v" or sys.argv[2] == "V":
				verbose = True #this program ignores all other arguments
	gmp = GMP_File(infile)
	if verbose:
		print gmp.info()
		print "Extracting files...\n"
	gmp.extractFiles()
	infile.close()
				
		
