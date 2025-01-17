###############################################################################
# Caching data files
################################################################################
barcode.getBarcodeDataFile <- function (ctx, datasetName) {
    dataFile <- getContextCacheFile(ctx, datasetName, "barcode", "barcodeAlleles.tab")
    dataFile
}
barcode.getBarcodeSeqFile <- function (ctx, datasetName) {
    seqFile  <- getContextCacheFile(ctx, datasetName, "barcode", "barcodeSeqs.tab")
    seqFile
}

barcode.getMetadata <- function (ctx, barcodeData) {
    barcodeSnps <- colnames(barcodeData)
    barcodeMeta <- ctx$config$barcodeMeta[barcodeSnps,]
    barcodeMeta
}

###############################################################################
# Barcode setting and caching
################################################################################
barcode.setDatasetBarcodes <- function (ctx, datasetName, barcodes, store=TRUE) {
    dataset <- ctx[[datasetName]]
    dataset$barcodes <- barcodes
    if (store) {
        barcodeDataFile <- barcode.getBarcodeDataFile (ctx, datasetName)
        writeSampleData(barcodes, barcodeDataFile)
        barcodeSeqFile <- barcode.getBarcodeSeqFile (ctx, datasetName)
        barcode.writeFasta (barcodes, barcodeSeqFile)
    }
    ctx[[datasetName]] <- dataset
    ctx
}

###############################################################################
# Barcode retrieval, validating and filtering
################################################################################
barcode.initializeBarcodes <- function (ctx, datasetName, loadFromCache=TRUE) {
    GRC_BARCODE_COL <- "GenBarcode"			# TODO  This may need to be configured globally

    config <- ctx$config
    dataset <- ctx[[datasetName]]

    barcodeDataFile <- barcode.getBarcodeDataFile (ctx, datasetName)

    if (loadFromCache & file.exists(barcodeDataFile)) {
        barcodeData <- readSampleData (barcodeDataFile)
        ctx <- barcode.setDatasetBarcodes (ctx, datasetName, barcodeData, store=FALSE)
    } else {
        # Get barcode alleles, and discard samples that have too much missingness
        barcodeMeta <- config$barcodeMeta
        #print (barcodeMeta)
        barcodeData <- barcode.getAllelesFromBarcodes (dataset$meta, GRC_BARCODE_COL, barcodeMeta)
        print(paste("Barcode alleles - Samples:", nrow(barcodeData), "x SNPs:", ncol(barcodeData)))
        print("Validating barcodes")
        barcode.validateBarcodeAlleles (barcodeData, barcodeMeta)

        # Filter the barcodes by typability, trying to throw away as little as possible
        #barcode.writeBarcodeStats (dataset, datasetName, barcodeData, "noFiltering")
        barcode.writeBarcodeStats (ctx, datasetName, barcodeData, "noFiltering")
        minSampleTypability <- config$minSampleTypability
        minSnpTypability    <- config$minSnpTypability
        print(paste("Filtering barcodes by typability (samples:", minSampleTypability, ", SNPs:", minSnpTypability, ")",sep=""))
        #
        # 1) remove all samples with <0.5 typability, so they affect less the removal of SNPs
        filteredData <- barcode.filterByTypability (barcodeData, bySnp=FALSE, minTypability=0.5)
        #
        # 2) Refine further, using the thresholds specified
        filteredData <- barcode.filterByTypability (filteredData, bySnp=TRUE,  minTypability=minSnpTypability)
        filteredData <- barcode.filterByTypability (filteredData, bySnp=FALSE, minTypability=minSampleTypability)
        barcodeData <- filteredData
        #
        #barcode.writeBarcodeStats (dataset, datasetName, barcodeData,
        barcode.writeBarcodeStats (ctx, datasetName, barcodeData,
                           paste("filtered-snps_", minSnpTypability, "-samples_", minSampleTypability, sep=""))
        print(paste("Barcode alleles after filtering - Samples:", nrow(barcodeData), "x SNPs:", ncol(barcodeData)))
        #
        ctx <- barcode.setDatasetBarcodes (ctx, datasetName, barcodeData, store=TRUE)
    }

    # Report missingness
    totalCalls <- nrow(barcodeData) * ncol(barcodeData)
    callCounts <- table(unlist(barcodeData))
    missingCalls <- callCounts["X"]
    missing <- missingCalls/totalCalls
    het <- callCounts["N"]/(totalCalls-missingCalls)
    print(paste("Missing:", missing, "- Het:", het))

    ctx
}
#
# Verify all alleles extracted are valid
#
barcode.validateBarcodeAlleles <- function (barcodeData, barcodeMeta) {
    snpCount <- nrow(barcodeMeta)				#; print(snpCount)
    if (ncol(barcodeData) != snpCount) {
        stop (paste("Number of barcode SNPs in the metadata (",snpCount,") does not match the length of the barcodes (",ncol(barcodeData),")",sep=""))
    }
    for (sIdx in 1:snpCount) {
        snpMeta <- barcodeMeta[sIdx,]				#; print(snpMeta)
        alleles <- c(snpMeta$Ref,snpMeta$Nonref,"X","N")	#; print(alleles)
        calls <- barcodeData[,sIdx]				#; print(calls)
        badIdx <- which(!(calls %in% alleles))			#; print(badIdx)
        if (length(badIdx) > 0) {
            bad <- badIdx[1]
            stop (paste("Bad allele found in SNP #",sIdx," in sample ",rownames(barcodeData)[bad],": found ",calls[bad,sIdx],sep=""))
        }
    }
}
#
# Convert barcodes into a dataframe of alleles, filtering both samples and barcode SNPs by typability
#
barcode.getAllelesFromBarcodes <- function(sampleMetadata, barcodeColumnName, barcodeMeta) {
    barcodes <- as.character(sampleMetadata[,barcodeColumnName])
    names(barcodes) <- rownames(sampleMetadata)

    # Eliminate all samples without barcode
    barcodes <- barcodes[which(barcodes != "-")]
    #print (length(barcodes))
    #print (barcodes[1:10])
    
    # Split the barcodes into constituent alleles
    #print (rownames(barcodeMeta))
    alleleMat <- extractBarcodeAlleles (barcodes, rownames(barcodeMeta))
    alleleData <- data.frame(alleleMat)
    rownames(alleleData) = names(barcodes);
    alleleData
}
#
###############################################################################
# Barcode Sample/SNP filtering
################################################################################
barcode.filterByTypability <- function(barcodeData, bySnp=FALSE, minTypability=0.75) {
    stats <- barcode.computeBarcodeStats (barcodeData, bySnp)
    result <- barcode.filterByTypabilityStats (barcodeData, stats, bySnp, minTypability)
    result
}

barcode.filterByHeterozygosity <- function(barcodeData, bySnp=FALSE, maxHeterozygosity=0.0) {
    stats <- barcode.computeBarcodeStats (barcodeData, bySnp)
    result <- barcode.filterByHeterozygosityStats (barcodeData, stats, bySnp, maxHeterozygosity)
    result
}

barcode.filterByStats <- function(barcodeData, bySnp=FALSE, minTypability=0.0, maxHeterozygosity=1.0) {
    stats <- barcode.computeBarcodeStats (barcodeData, bySnp)
    result <- barcode.filterByTypabilityStats (barcodeData, stats, bySnp, minTypability)
    result <- barcode.filterByHeterozygosityStats (result, stats, bySnp, maxHeterozygosity)
    result
}

barcode.filterByTypabilityStats <- function(barcodeData, stats, bySnp, minTypability) {
    selectIdx <- which(stats$typable >= minTypability)
    result <- if (bySnp) barcodeData[,selectIdx] else barcodeData[selectIdx,]
    result
}

barcode.filterByHeterozygosityStats <- function(barcodeData, stats, bySnp, maxHeterozygosity) {
    selectIdx <- which(stats$het <= maxHeterozygosity)
    result <- if (bySnp) barcodeData[,selectIdx] else barcodeData[selectIdx,]
    result
}

barcode.computeBarcodeStats <- function (bcodes, bySnp) {
    margin <- if (bySnp) 2 else 1
    occurrences <- if (bySnp) nrow(bcodes) else ncol(bcodes)
    rnames <- if (bySnp) colnames(bcodes) else rownames(bcodes)

    missCounts <- apply(bcodes, margin, function(x) length(which(x=="X")))
    hetCounts <- apply(bcodes, margin, function(x) length(which(x=="N")))

    missing <- (missCounts / occurrences)
    typabile <- 1 - missing;
    valid   <- (occurrences - missCounts)
    het     <- (hetCounts / valid)

    stats <- data.frame(missing, typabile, het)
    colnames(stats) <- c("missing", "typable", "het")
    rownames(stats) <- rnames
    stats
}

barcode.writeBarcodeStats <- function(ctx, datasetName, barcodeData, suffix="") {
    if (nchar(suffix) > 0) {
        suffix <- paste(".", suffix, sep="")
    }
    stats <- barcode.computeBarcodeStats (barcodeData, bySnp=TRUE)
    statsFilename <- paste("stats-snps", suffix, ".tab",  sep="")
    statsFile  <- getContextCacheFile(ctx, datasetName, "barcode", statsFilename)
    writeLabelledData (stats, "Snp", statsFile)

    stats <- barcode.computeBarcodeStats (barcodeData, bySnp=FALSE)
    statsFilename  <- paste("stats-samples", suffix, ".tab",  sep="")
    statsFile  <- getContextCacheFile(ctx, datasetName, "barcode", statsFilename)
    writeLabelledData (stats, "Sample", statsFile)
}

###############################################################################
# Sequence Output
################################################################################
barcode.writeFasta <- function(allelesData, genosFilename) {
  strData <- data.frame(lapply(allelesData, as.character), stringsAsFactors=FALSE)
  txt <- c()
  sampleNames <- rownames(allelesData)
  for (mIdx in 1:length(sampleNames)) {
    header <- paste (">",sampleNames[mIdx],sep='')
    seq <- paste (strData[mIdx,], collapse='')
    txt <- c(txt, header, seq)
  }
  writeLines(txt, genosFilename)
}
