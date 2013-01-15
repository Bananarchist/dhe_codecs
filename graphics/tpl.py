import os, sys, png
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
    def __init__(self, *args, **kwargs):
        #assume infile is functional
        print kwargs.viewitems()
        if "file" in kwargs.keys() or "filename" in kwargs.keys():
            try: self.infile = kwargs.get("file", open(kwargs["filename"], "rb"))
            except:
                print "Failed to open file"
                return
        if not TPL_File.isTPL(self.infile):
            pass #something better needs to happen
        self.TPLFileName = self.infile.name.split(os.sep)[-1]
        self.infile.seek(0)
        #start processing file
        self.textureCount, self.headerSize = unpack("<II", self.infile.read(8))
        self.textures = []
        self.sprites = -1
        for i in xrange(self.textureCount):
            self.infile.seek(self.headerSize + i * 8)
            self.textures.append(dict())
            self.textures[i]['tInfoOffset'], self.textures[i]['pInfoOffset'] = unpack("<II", self.infile.read(8))
            self.infile.seek(self.textures[i]['tInfoOffset'])
            tInfo = unpack("<HHHHI", self.infile.read(12))
            self.textures[i]['tHeight'] = tInfo[0]
            self.textures[i]['tWidth'] = tInfo[1]
            self.textures[i]['tFormat'] = tInfo[3] #tInfo[2] doesn't matter, I think
            self.textures[i]['tOffset'] = tInfo[4]
            if self.textures[i]['pInfoOffset'] != 0:
                self.infile.seek(self.textures[i]['pInfoOffset'])
                pInfo = dict()
                pInfo['colors'], pInfo['u'], pInfo['offset'] = unpack("<HHI", self.infile.read(8))
                p = []
                self.infile.seek(pInfo['offset'])
                c = unpack("<" + str(pInfo['colors'] * 4) + "B", self.infile.read(pInfo['colors'] * 4)) # note for writing that colors are in BGRA format
                for j in xrange(pInfo['colors']):
                    p.append((c[j*4], c[j*4+1], c[j*4+2], c[j*4+3])) # switch!
                self.textures[i]['pInfo'] = pInfo
                self.textures[i]['palette'] = p
            if self.textures[i]['tFormat'] == 0xFFFF:
                self.sprites = i
        if self.sprites != -1:
            pass
        else:
            pass
    def extractFile(self, fileIndex = 0, targetDir = None, fileName = None):
        #setup
        ti = self.textures[fileIndex]
        # we'll turn this on once we know there aren't multiple sprite indices possible
        #if (self.sprites != -1) and (fileIndex != self.sprites): return
        pd = [] # pixel data
        of = None #output file
        bytes = ti['tHeight'] * ti['tWidth']
        den = 2 if (ti['tFormat'] == 4) else 1
        if not targetDir: targetDir = os.getcwd()
        if not fileName: fileName = "%s_%i.png" % (self.TPLFileName, fileIndex)
        try: 
            of = open(targetDir + os.sep + fileName, "wb")
        except:
            print "Failed to open file %s in dir %s" % (filename, targetDir)
        #extraction
        self.infile.seek(ti['tOffset'])
        td = unpack("<" + str(bytes/den) + "B", self.infile.read(bytes/den))
        if ti['tFormat'] == 4:
            td = [item for sublist in [[m&0x0F, (m&0xF0)>>4] for m in td] for item in sublist] #split bytes and then flatten list
        if ti['tFormat'] != 0xFFFF:
            for j in xrange(ti['tHeight']):
                for k in xrange(ti['tWidth']):
                    pd.append(td[((j/8) * (ti['tWidth']/(16*den)) * (128*den)) + ((j%8) * (16*den)) + (k%(16*den)) + ((k/(16*den)) * (128*den))])
                        # x*den = adjust for 2 pix/byte versus 1 pix/byte, notes assume 1 pix/byte
                        # 128 * (j/8) * (w/16): which 4-tile block
                        # 16 * (j%8): vertical position
                        # (k%16): horizontal position
                        # 128 * (k/16): horizontal block 
            img = png.Writer(ti['tWidth'], ti['tHeight'], None, False, False, 8, ti['palette'])
            img.write_array(of, pd)
        else:
            pass # 0xFFFF format
    def extractAll(self, targetDir = None):
        pass
    def info(self):
        pass
    @staticmethod
    def isTPL(infile):
        pass



if __name__=="__main__":
    pass
