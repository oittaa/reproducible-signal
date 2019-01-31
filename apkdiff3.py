#! /usr/bin/env python3

import sys
from zipfile import ZipFile

class ApkDiff:

    # You might need to add "resources.arsc" to the list due to a bug. https://issuetracker.google.com/issues/110237303
    IGNORE_FILES = ["META-INF/MANIFEST.MF", "META-INF/SIGNAL_S.RSA", "META-INF/SIGNAL_S.SF"]

    def compare(self, sourceApk, destinationApk):
        sourceZip      = ZipFile(sourceApk, 'r')
        destinationZip = ZipFile(destinationApk, 'r')

        if self.compareManifests(sourceZip, destinationZip) and self.compareEntries(sourceZip, destinationZip) == True:
            print("APKs match!")
        else:
            print("APKs don't match!")

    def compareManifests(self, sourceZip, destinationZip):
        sourceEntrySortedList      = sorted(sourceZip.namelist())
        destinationEntrySortedList = sorted(destinationZip.namelist())

        for ignoreFile in self.IGNORE_FILES:
            while ignoreFile in sourceEntrySortedList: sourceEntrySortedList.remove(ignoreFile)
            while ignoreFile in destinationEntrySortedList: destinationEntrySortedList.remove(ignoreFile)

        if len(sourceEntrySortedList) != len(destinationEntrySortedList):
            print("Manifest lengths differ!")

        for (sourceEntryName, destinationEntryName) in zip(sourceEntrySortedList, destinationEntrySortedList):
            if sourceEntryName != destinationEntryName:
                print("Sorted manifests don't match, %s vs %s" % (sourceEntryName, destinationEntryName))
                return False

        return True

    def compareEntries(self, sourceZip, destinationZip):
        sourceInfoList      = filter(lambda sourceInfo: sourceInfo.filename not in self.IGNORE_FILES, sourceZip.infolist())
        destinationInfoList = filter(lambda destinationInfo: destinationInfo.filename not in self.IGNORE_FILES, destinationZip.infolist())

        if len(list(sourceInfoList)) != len(list(destinationInfoList)):
            print("APK info lists of different length!")
            return False

        for sourceEntryInfo in sourceInfoList:
            for destinationEntryInfo in list(destinationInfoList):
                if sourceEntryInfo.filename == destinationEntryInfo.filename:
                    sourceEntry      = sourceZip.open(sourceEntryInfo, 'r')
                    destinationEntry = destinationZip.open(destinationEntryInfo, 'r')

                    if self.compareFiles(sourceEntry, destinationEntry) != True:
                        print("APK entry %s does not match %s!" % (sourceEntryInfo.filename, destinationEntryInfo.filename))
                        return False

                    destinationInfoList.remove(destinationEntryInfo)
                    break

        return True

    def compareFiles(self, sourceFile, destinationFile):
        sourceChunk      = sourceFile.read(1024)
        destinationChunk = destinationFile.read(1024)

        while sourceChunk != "" or destinationChunk != "":
            if sourceChunk != destinationChunk:
                return False

            sourceChunk      = sourceFile.read(1024)
            destinationChunk = destinationFile.read(1024)

        return True

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: apkdiff <pathToFirstApk> <pathToSecondApk>")
        sys.exit(1)

    ApkDiff().compare(sys.argv[1], sys.argv[2])
