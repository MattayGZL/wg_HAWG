### ============================================================================
### Document Assessment
### ============================================================================

old.opt           <- options("width","scipen")
options("width"=75,"scipen"=1000)

sam.out.file      <- FLSAM.out(NSH,NSH.tun,NSH.sam,format="TABLE 2.6.3.%i North Sea Herring.")
write(sam.out.file,file=paste(output.base,"sam.out",sep="."))
options("width"=old.opt$width,"scipen"=old.opt$scipen)
#
##And finally, write the results out in the lowestoft VPA format for further analysis
writeFLStock(NSH,output.file=file.path(output.dir,"NSAS_47d3_"))

stockSummaryTable <- cbind(rec(NSH.sam)$year,
                           rec(NSH.sam)$value,      rec(NSH.sam)$lbnd,    rec(NSH.sam)$ubnd,
                           tsb(NSH.sam)$value,      tsb(NSH.sam)$lbnd,    tsb(NSH.sam)$ubnd,
                           ssb(NSH.sam)$value,      ssb(NSH.sam)$lbnd,    ssb(NSH.sam)$ubnd,
                           catch(NSH.sam)$value,    catch(NSH.sam)$lbnd,  catch(NSH.sam)$ubnd,
                           catch(NSH.sam)$value / ssb(NSH.sam)$value, catch(NSH.sam)$lbnd / ssb(NSH.sam)$lbnd, catch(NSH.sam)$ubnd / ssb(NSH.sam)$ubnd,
                           fbar(NSH.sam)$value,     fbar(NSH.sam)$lbnd,   fbar(NSH.sam)$ubnd,
                           c(quantMeans(harvest(NSH.sam)[ac(0:1),])),
                           c(sop(NSH),NA),
                           c(catch(NSH),NA))
colnames(stockSummaryTable) <-
  c("Year",paste(rep(c("Recruits Age 0 (Thousands)","Total biomass (tonnes)","Spawing biomass (tonnes)",
                       "Landings (tonnes)","Yield / SSB (ratio)","Mean F ages 2-6"),each=3),c("Mean","Low","High")),"Mean F ages 0-1","SoP (%)","WG Catch")
stockSummaryTable[nrow(stockSummaryTable),] <- NA
stockSummaryTable[nrow(stockSummaryTable),"Spawing biomass (tonnes) Mean"] <- 2271364
stockSummaryTable[nrow(stockSummaryTable),2:4] <- c(rec(NSH.sam)$value[nrow(rec(NSH.sam))],rec(NSH.sam)$lbnd[nrow(rec(NSH.sam))],rec(NSH.sam)$ubnd[nrow(rec(NSH.sam))])
write.csv(stockSummaryTable,file=file.path(output.dir,paste(name(NSH),"stockSummaryTable.csv",sep="_")))
options("width"=old.opt$width,"scipen"=old.opt$scipen)
