import os, sys, png
from struct import *


class TPL_DBlock:
    """How to read the image data into discrete blocks for constructing images"""
    def __init__(self, block):
        self.hShift, self.vShift, self.row, self.column, self.hrle, self.vrle = block[0], block[1] << 1, (block[2] & 0xFC00) >> 7, block[2] & 0x03FF, block[3], block[4] >> 2
    def __str__(self):
        return "DB Block {Shift: (%i, %i), Start: (%i, %i), Runlength: (%i, %i)}" % (self.hShift, self.vShift, self.column, self.row, self.hrle, self.vrle)
    def __repr__(self):
        return self.__str__()

# No other methodss necessary?

class TPL_File:
    def __init__(self, *args, **kwargs):
        #assume infile is functional
        #print kwargs.viewitems()
        if "file" in kwargs.keys() or "filename" in kwargs.keys():
            try: self.infile = kwargs.get("file", open(kwargs["filename"], "rb"))
            except:
                print "Failed to open file"
                return
        if not TPL_File.isTPL(self.infile):
            pass #something better needs to happen
        self.TPLFileName = self.infile.name.split(os.sep)[-1]
        self.infile.seek(0, 2)
        self.fileLength = self.infile.tell()
        self.infile.seek(0)
        #start processing file
        self.textureCount, self.headerSize = unpack("<II", self.infile.read(8))
        self.spriteCount = 0
        self.textures = []
        self.spriteData = None
        self.td = None
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
            	if not self.spriteData:
                    self.spriteData = [self.textures[i]]
                    for tdat in self.textures:
                        if tdat['tFormat'] != 0xFFFF:
                            self.td = tdat
            	else:
            		self.spriteData.append(self.textures[i])
        if self.spriteData:
            self.textureCount -= len(self.spriteData)
            for i in xrange(len(self.spriteData)):
                self.textures.remove(self.spriteData[i])
                self.infile.seek(self.spriteData[i]['tOffset'])
                self.spriteData[i]['shl'], self.spriteData[i]['sCount'] = unpack("<II", self.infile.read(8))
                if self.spriteData[i]['shl'] != 8:
                    print "Strange Sprite Header length %x for sprite %i" % (self.spriteData[i]['shl'], i)
                    continue
                else:
                    self.spriteCount += 1
                cb = []
                self.dbs = 0
                for j in xrange(self.spriteData[i]['sCount']):
                    self.infile.seek(self.spriteData[i]['tOffset'] + j * 8 + 8)
                    cb.append({})
                    cb[j]['DBOffset'], cb[j]['u1'], cb[j]['bytes'], cb[j]['DBCount'] = unpack("<IBHB", self.infile.read(8))
                    self.infile.seek(self.spriteData[i]['tOffset'] + cb[j]['DBOffset'])
                    cb[j]['db'] = []
                    mh = 0
                    mw = 0
                    self.dbs += cb[j]['DBCount']
                    for k in xrange(cb[j]['DBCount']):
                        d = TPL_DBlock(unpack("<BBHBB", self.infile.read(6)))
                        if d.hShift + d.hrle > mw: mw = d.hShift + d.hrle
                        if d.vShift + d.vrle > mh: mh = d.vShift + d.vrle
                        cb[j]['db'].append(d)
                    cb[j]['height'] = mh
                    cb[j]['width'] = mw
                self.spriteData[i]['cb'] = cb
                
    def extractAll(self, targetDir=None, filenameRoot=None):
        print "%i textures and %i sprites" % (self.textureCount, self.spriteCount)
        if not targetDir:
            targetDir = os.getcwd()
            if ((self.spriteCount > 0) and (self.textureCount + self.spriteCount > 1)) or (self.textureCount > 1):
                targetDir = os.path.join(targetDir, self.TPLFileName.split('.')[0])
        if not os.access(targetDir, os.F_OK):
            try: os.mkdir(targetDir)
            except OSError:
                print "Couldn't access " + targetDir
                return False
        if (self.spriteCount > 0 and self.textureCount > 1) or (self.spriteCount == 0):
            print "Processing Textures"
            for i in xrange(self.textureCount):
                if self.td == self.textures[i]: continue
                if filenameRoot: filenameRoot = "%s_tex%i.png" % (filenameRoot, i)
                self.extractTexture(i, filenameRoot, targetDir)
        if self.spriteCount > 0:
            self.td['textureData'] = self.e_t(self.td)
            print "Processing Sprites"
            for i in xrange(self.spriteCount):
                if self.spriteData[i]['shl'] != 8:
                    print "Skipping confusing sprite data"
                    continue
                for j in xrange(self.spriteData[i]['sCount']):
                    if filenameRoot: filenameRoot = "%s_spr%i_%j.png" % (filenameRoot, i, j)
                    self.extractSprite(j, filenameRoot, targetDir)
            self.td.pop("textureData")
        print "Done"
        
    def extractTexture(self, texIndex, filename=None, targetDir=os.getcwd()):
        if texIndex >= len(self.textures):
            raise Exception, "texIndex outside of list range"
        if not filename: filename = "%s_tex%i.png" % (self.TPLFileName.split('.')[0], texIndex)
        img = png.Writer(self.textures[texIndex]['tWidth'], self.textures[texIndex]['tHeight'], None, False, False, 8, self.textures[texIndex]['palette'])
        with open(os.path.join(targetDir, filename), "wb") as oot:
            img.write_array(oot, self.e_t(texIndex))

    def extractSprite(self, spriteIndex, filename=None, targetDir=os.getcwd()):
        if spriteIndex >= self.spriteData[0]['sCount']:
            raise Exception, "spriteIndex outside of list range"
        if not filename: filename = "%s_spr%i.png" % (self.TPLFileName.split('.')[0], spriteIndex)
        img = png.Writer(self.spriteData[0]['cb'][spriteIndex]['width'], self.spriteData[0]['cb'][spriteIndex]['height'], None, False, False, 8, self.td['palette'])
        with open(os.path.join(targetDir, filename), "wb") as oot:
            img.write_array(oot, self.e_s(spriteIndex))

    def e_s(self, spr): #extract sprite, return array data
        si = 0 #precautionary
        s = self.spriteData[si]['cb'][spr]
        if self.td.has_key("textureData"):
            t = self.td['textureData']
        else:
            t = self.e_t(self.td)
        pd = []
        for i in xrange(s['height'] * s['width']):
            pd.append(0) 
        for d in s['db']: #for each d block
#            row = (d.readStart & 0xFC00) >> 7
 #           column = d.readStart & 0x03FF
  #          y1 = row * self.td['tWidth']
   #LOOK:         x1 = column % self.td['tWidth']
            r = (d.row * self.td['tWidth']) + (d.column % self.td['tWidth'])
            for y in xrange(d.vrle): #for each row to read
                for x in xrange(d.hrle): # for each column to read
                    tp = r + (y * self.td['tWidth']) + x
                    if x + (d.column % self.td['tWidth']) >= self.td['tWidth']: 
                        tp += self.td['tWidth'] * 8
                    sp = (d.vShift + y) * s['width'] + (d.hShift + x)    
                    assert tp < len(t), 'tp %i outside t %i range' % (tp, len(t))
                    assert sp < len(pd), 'sp outside pd range' 
                    pd[sp] = t[tp]
        return pd

    def e_t(self, tex): #extract texture, return array data
        if tex.__class__ == (1).__class__:
            t = self.textures[tex]
        else:
            if tex.has_key("textureData"): return tex.pop("textureData")
            t = tex
        pd = [] # pixel data
        bytes = t['tHeight'] * t['tWidth']
        den = 2 if (t['tFormat'] == 4) else 1
        #extraction
        self.infile.seek(t['tOffset'])
        td = unpack("<" + str(bytes/den) + "B", self.infile.read(bytes/den))
        if t['tFormat'] == 4:
            td = [item for sublist in [[m&0x0F, (m&0xF0)>>4] for m in td] for item in sublist] #split bytes and then flatten list
        for j in xrange(t['tHeight']):
            for k in xrange(t['tWidth']):
                pd.append(td[((j/8) * (t['tWidth']/(16*den)) * (128*den)) + ((j%8) * (16*den)) + (k%(16*den)) + ((k/(16*den)) * (128*den))])
        return pd

    def info(self):
        pass

    @staticmethod
    def isTPL(infile):
        #the issue here, since there's no marker for TPL files in them as Sting uses them, is how to identify
        pass



if __name__=="__main__":
    pass
