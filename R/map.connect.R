###############################################################################
# Measures of connectedness
###############################################################################
#
connectMap.getConnectednessMeasures <- function() {
    allMeasures <- c("similarity","meanDistance")
    allMeasures
}

###############################################################################
# Map Aggregated Measure Analysis
################################################################################
#
connectMap.execute <- function(userCtx, datasetName, sampleSetName, mapType, baseMapInfo, aggregation, measures, params) {
    sampleSet <- userCtx$sampleSets[[sampleSetName]]
    ctx <- sampleSet$ctx
    dataset <- ctx[[datasetName]]
    
    # Get the output folders
    dataOutFolder <- getOutFolder(ctx, sampleSetName, c(paste("map", mapType, sep="-"), "data"))
    # Get the sample metadata
    sampleMeta <- dataset$meta
    
    # If "similarity" is one of the measures, remove it and add one measure for each similarity threshold (e.g. "similarity-ge0.80")
    measures <- connectMap.expandMeasures(measures, params)
    
    # Silly trick to make the package checker happy... :-(
    lon <- lat <- label <- NULL

    # Now compute the aggregation units, the values to be plotted, and make the map
    for (aggIdx in 1:length(aggregation)) {
        aggLevel <- as.integer(aggregation[aggIdx])        					#; print(aggLevel)
        aggLevelIdx <- aggLevel + 1

        # Get the aggregated data for the aggregation units
        aggUnitData <- map.getAggregationUnitData (ctx, datasetName, aggLevel, sampleSetName, mapType, params, dataOutFolder)	#; print(aggUnitData)
        aggUnitPairData <- connectMap.estimateMeasures (ctx, datasetName, sampleSetName, aggLevel, aggUnitData, mapType, measures, params, dataOutFolder)	#; print(aggUnitPairData)

        for (mIdx in 1:length(measures)) {
            measure <- measures[mIdx]						#; print(measure)
            if (connectMap.filterThreshold (measure)) {
                minValues <- as.numeric(analysis.getParam(paste("map.connect", measure, "min", sep="."), params))
            } else {
                minValues <- 0
            }									#; print(minValues)
            for (mvIdx in 1:length(minValues)) {
                minValue <- minValues[mvIdx]
            
                # Select the aggregation unit pairs to be plotted
                # In this case, those thatwith value above the threshold
                mValues <- aggUnitPairData[,measure]
                selAggUnitPairData <- aggUnitPairData[which(mValues > minValue),]
                
                # Sort the pairs so that higher values get plotted last
                mValues <- selAggUnitPairData[,measure]
                selAggUnitPairData <- selAggUnitPairData[order(mValues),]
                
                # Do the actual plot, starting with the background map
                mapPlot <- baseMapInfo$baseMap
                
                # This function replaces aes_strng() allowing the use of column names with dashes
                fn_aesString <- get("aes_string", asNamespace("ggplot2"))
                aes_string2 <- function(...){
                    args <- lapply(list(...), function(x) sprintf("`%s`", x))
                    #do.call(aes_string, args)
                    do.call(fn_aesString, args)
                }
                
                # Now plot the connections
                mapPlot <- mapPlot +
                    ggplot2::geom_curve(aes_string2(x="Lon1", y="Lat1", xend="Lon2", yend="Lat2", size=measure, colour=measure),
                                        data=selAggUnitPairData, curvature=0.2, alpha=0.75) +
                    ggplot2::scale_size_continuous(guide="none", range=c(0.25, 4)) +          					# scale for edge widths
                    ggplot2::scale_colour_gradientn(colours=c("skyblue1","midnightblue"))
                
                # Now add the markers
                mapPlot <- mapPlot +
                    ggplot2::geom_point(aes_string2(x="Longitude", y="Latitude"), data=aggUnitData, size=4, shape=19, col="red")
    	    
                # If we need to show aggregation unit names, we need to compute the label positioning and plot
                showMarkerNames <- analysis.getParam ("map.markerNames", params)
                if (showMarkerNames) {
                    lp <- map.computeLabelParams (aggUnitData, baseMapInfo)
                    mapPlot <- mapPlot +
                        ggrepel::geom_label_repel(ggplot2::aes(x=lon, y=lat, label=label), data=lp, size=4.5, fontface="bold", color="darkgray",
                                                  hjust=lp$just, vjust=0.5, nudge_x=lp$x, nudge_y=lp$y, label.padding=grid::unit(0.2, "lines"))
                }
                	    
                # Now add the decorative elements
                mapPlot <- mapPlot +
                           ggplot2::theme(
                               plot.title = ggplot2::element_text(face = "bold",size = ggplot2::rel(1.2), hjust = 0.5),
                               panel.background = ggplot2::element_rect(colour = NA),
                               plot.background = ggplot2::element_rect(colour = NA),
                               axis.title = ggplot2::element_text(face = "bold", size = ggplot2::rel(1)),
                               axis.title.y = ggplot2::element_text(angle = 90,vjust = 2),
                               axis.title.x = ggplot2::element_text(vjust = -0.2))
    	    
    	        # Save to file. the size in inches is given in the config.
    	        mapSize  <- analysis.getParam ("plot.size", params)
    	        plotFolder <- getOutFolder(ctx, sampleSetName, c(paste("map", mapType, sep="-"), "plots"))
                aggLabel <- map.getAggregationLabels(aggLevel)
                graphicFilenameRoot  <- paste(plotFolder, paste("map", sampleSetName, aggLabel, measure, sep="-"), sep="/")
                if (connectMap.filterThreshold (measure)) {
    	            graphicFilenameRoot  <- paste(graphicFilenameRoot, paste("ge", format(minValue, digits=2, nsmall=2), sep=""), sep="-")
                }
                ggplot2::ggsave(plot=mapPlot, filename=paste(graphicFilenameRoot,"png",sep="."), device="png", 
                                width=mapSize$width, height=mapSize$height, units="in", dpi=300)
            }
        }
    }
}

connectMap.filterThreshold  <- function(measure) {
    measure %in% c("meanDistance")
}

connectMap.expandMeasures <- function(measures, params) {
    result <- c()
    if ("ALL" %in% measures) {
        measures <- connectMap.getConnectednessMeasures()
    }
    for (mIdx in 1:length(measures)) {
        measure <- measures[mIdx]
        if (measure == "similarity") {
            levels <- as.numeric(analysis.getParam("map.connect.identity.min", params))
            for (lIdx in 1 : length(levels)) {
                measureStr <- paste("similarity-ge", format(levels[lIdx], digits=2, nsmall=2), sep="")
                result <- c(result, measureStr)
            }
        } else {
            result <- c(result, measure)
        }
    }
    result
}

connectMap.getMeasureLevel <- function(measure, prefix) {
    if (!startsWith(measure, prefix)) {
        return (NA)				#; print("Incorrect prefix")
    }
    level <- substring(measure,nchar(prefix)+1)	#; print(level)
    as.numeric(level)
}

connectMap.estimateMeasures <- function (ctx, datasetName, sampleSetName, aggLevel, aggUnitData, mapType, measures, params, dataFolder)	{
    dataset <- ctx[[datasetName]]
    sampleMeta   <- dataset$meta
    barcodeData  <- dataset$barcodes
    distData     <- dataset$distance

    # Create aggregation index for each sample (the id of the aggregation unit where the sample originates)
    sampleGids <- as.character(map.getAggregationUnitIds (aggLevel, sampleMeta))
    sampleIds <- rownames(sampleMeta)
    
    # Get all aggregation units
    aggUnitGids <- rownames(aggUnitData)						#; print(aggUnitGids) ; print(head(aggUnitData))
    
    # Get the data for all aggregation units
    measureData <- NULL
    for (a1Idx in 1:(length(aggUnitGids)-1)) {
        for (a2Idx in (a1Idx+1):length(aggUnitGids)) {
            # Get the sample data
            gid1 <- aggUnitGids[a1Idx]							#; print(gid1)
            name1 <- aggUnitData$AdmDivName[a1Idx]					#; print(name1)
            lat1 <- aggUnitData$Latitude[a1Idx]
            lon1 <- aggUnitData$Longitude[a1Idx]
            samples1 <- sampleIds[which(sampleGids == gid1)]				#; print(length(samples1))
            #
            gid2 <- aggUnitGids[a2Idx]							#; print(gid2)
            name2 <- aggUnitData$AdmDivName[a2Idx]					#; print(name2)
            lat2 <- aggUnitData$Latitude[a2Idx]
            lon2 <- aggUnitData$Longitude[a2Idx]
            samples2 <- sampleIds[which(sampleGids == gid2)]				#; print(length(samples2))
            #
            pairDist <- distData[samples1,samples2]					#; print(dim(pairDist))
            #
            # Get the admin division values from the first sample of this unit (assuming the values are the same for all)
            mValues <- connectMap.estimateDistMeasures (pairDist, measures)		#; print (mValues)
            cValues <- c(gid1, gid2, name1, name2, lat1, lon1, lat2, lon2, mValues)
            measureData <- rbind(measureData, cValues)
        }
    }
    aggUnitPairData <- data.frame(measureData)						#; print (dim(aggUnitPairData))
    nc <- ncol(aggUnitPairData)
    aggUnitPairData[,5:nc] <- sapply(aggUnitPairData[,5:nc], as.numeric)		#; print(ncol(aggUnitPairData))
    colnames(aggUnitPairData) <- c("Unit1", "Unit2", "UnitName1", "UnitName2", "Lat1", "Lon1", "Lat2", "Lon2", measures)
    
    # Write out the aggregation unit data to file
    aggDataFilename  <- paste(dataFolder, "/AggregatedPairData-", sampleSetName, "-", aggLevel, ".tab", sep="")
    utils::write.table(aggUnitPairData, file=aggDataFilename, sep="\t", quote=FALSE, row.names=FALSE)

    aggUnitPairData
}

connectMap.estimateDistMeasures <- function (distData, measures) {
    result <- c()
    dist <- unlist(distData)
    for (mIdx in 1:length(measures)) {
        measure <- measures[mIdx]
        if (startsWith(measure, "similarity")) {
            level <- connectMap.getMeasureLevel (measure, "similarity-ge")	#; print(level)
            maxDist = 1.0 - level						#; print(maxDist)
            value <- length(which(dist <= maxDist)) / length(dist)
        } else if (measure == "meanDistance") {
            value <- 1 - mean(dist) 
        } else {
            stop(paste("Invalid distance connectedness measure:", measure))
        }
        result <- c(result, value)
    }
    result
}

