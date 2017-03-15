#- Find F multipliers for fleet A,B,C and D, based on Ftarget for A,B and
#   moving Ctarget for C and fixed Ctarget for D

source(file=file.path("./temp_forecast_readStfData.r"))

iTer        <- 1
mixprop     <- Csplit #NSAS proportion in C-fleet: 3-year average
advCatchWB  <- WBSScatch #advised WBSS catch in the forecast year

#stf@stock.n[,FcY] <- stf@stock.n[,FcY]*3
res <- optim(par=rep(1,dims(stf)$unit),find.FABC,
                 Fs=stf@harvest[,FcY,,,,iTer,drop=T],
                 Ns=stf@stock.n[,FcY,1,,,iTer,drop=T],
                 Wts=stf@stock.wt[,FcY,1,,,iTer,drop=T],
                 CWts=stf@catch.wt[,FcY,,,,iTer,drop=T],
                 fspwns=stf@harvest.spwn[,FcY,1,,,iTer,drop=T],
                 mspwns=stf@m.spwn[,FcY,1,,,iTer,drop=T],
                 mats=stf@mat[,FcY,1,,,iTer,drop=T],
                 Ms=stf@m[,FcY,1,,,iTer,drop=T],f01=f01,f26=f26,
                 Tcs=iter(TACS[,c(ImY,FcY)],iTer),
                 mixprop=mixprop,
                 lower=rep(0.01,4),method="L-BFGS-B",control=list(maxit=100))$par

#- Update harvest accordingly
stf@harvest[,FcY]         <- sweep(stf@harvest[,FcY],c(3,6),res,"*")

#- Calculate catches based on new harvest pattern
for(i in dms$unit){
  stf@catch.n[,FcY,i]     <- stf@stock.n[,FcY,i]*(1-exp(-unitSums(stf@harvest[,FcY])-stf@m[,FcY,i]))*(stf@harvest[,FcY,i]/(unitSums(stf@harvest[,FcY])+stf@m[,FcY,i]))
  stf@catch[,FcY,i]       <- computeCatch(stf[,FcY,i])
  stf@landings.n[,FcY,i]  <- stf@catch.n[,FcY,i]
  stf@landings[,FcY,i]    <- computeLandings(stf[,FcY,i])
}

stf@catch[,FcY,"A"] #forecasted A-fleet TAC in FcY
#test if IAV cap on TAC needs to be applied
abs((stf@catch[,FcY,"A"] - TACS.orig[,ImY,"A"])/TACS.orig[,ImY,"A"]) > 0.15 #forecasted TAC is not smaller than ImY TAC-15%

for(i in 1:20){

  #- Check if catches are more than 15% from the year before. And if so, adjust
  idxup                     <- which(stf@catch[,FcY,"A"] > TACS.orig[,ImY,"A"]*1.15)
  idxdown                   <- which(stf@catch[,FcY,"A"] < TACS.orig[,ImY,"A"]*0.85)
  stf@catch[,FcY,"A",,,idxup]   <- TACS.orig[,ImY,"A",,,idxup]   *1.15
  stf@catch[,FcY,"A",,,idxdown] <- TACS.orig[,ImY,"A",,,idxdown] *0.85
  #- If adjusted, recalculate harvest pattern
  stf@catch[,FcY,"C"]       <- (0.057 * sum(stf@catch[,FcY,c("A")]) + 0.41 * advCatchWB) *mixprop #combined C-fleet TAC

  stf@harvest[,FcY]         <- fleet.harvest(stk=stf,iYr=FcY,TACS=stf@catch[,FcY])

  #- Check the F target according to adjusted TAC
  ssb                       <- quantSums(stf@stock.n[,FcY,1] * stf@stock.wt[,FcY,1]*stf@mat[,FcY,1]*exp(-unitSums(stf@harvest[,FcY])*stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]))
  resA <- resB              <- numeric(dims(stf)$iter)
  idx                       <- which(ssb < 0.8e6,arr.ind=T)
  if(length(idx)>0){
    resA[idx[,6]]           <- 0.1
    resB[idx[,6]]           <- 0.04
  }
  idx                       <- which(ssb >= 0.8e6 & ssb <= 1.5e6,arr.ind=T)
  if(length(idx)>0){
    resA[idx[,6]]           <- 0.16/0.7*((ssb[,,,,,idx]-0.8e6)/1e6)+0.1
    resB[idx[,6]]           <- 0.05
  }
  idx                       <- which(ssb > 1.5e6,arr.ind=T)
  if(length(idx)>0){
    resA[idx[,6]]           <- 0.26
    resB[idx[,6]]           <- 0.05
  }


  #-if Ftarget is off by more than 10%, make an adjustment
  outidx                    <- which(apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T) <  0.9 * resA |
                                     apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T) >  1.1 * resA)
  inidx                     <- which(apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T) >= 0.9 * resA &
                                     apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T) <= 1.1 * resA)
  #- If outside this range, do not apply TAC constraint and use 15% cap on F
  if(length(outidx)>0){
    sidx                    <- which((apply(unitSums(stf@harvest[f26,FcY,,,,outidx]),2:6,mean,na.rm=T)) <  0.9 * resA[outidx])
    bidx                    <- which((apply(unitSums(stf@harvest[f26,FcY,,,,outidx]),2:6,mean,na.rm=T)) >  1.1 * resA[outidx])

    if(length(sidx)>0) stf@harvest[,FcY,"A",,,outidx[sidx]]       <- sweep(stf@harvest[,FcY,"A",,,outidx[sidx]],2:6,
                                                                      ((resA[outidx[sidx]] * 0.9) - apply(unitSums(stf@harvest[f26,FcY,c("B","C","D"),,,outidx[sidx]]),2:6,mean,na.rm=T)) /
                                                                        apply(unitSums(stf@harvest[f26,FcY,"A",,,outidx[sidx]]),2:6,mean,na.rm=T),"*")
    if(length(bidx)>0) stf@harvest[,FcY,"A",,,outidx[bidx]]       <- sweep(stf@harvest[,FcY,"A",,,outidx[bidx]],2:6,
                                                                      ((resA[outidx[bidx]] * 1.1) - apply(unitSums(stf@harvest[f26,FcY,c("B","C","D"),,,outidx[bidx]]),2:6,mean,na.rm=T)) /
                                                                        apply(unitSums(stf@harvest[f26,FcY,"A",,,outidx[bidx]]),2:6,mean,na.rm=T),"*")
  }
  #-if Ftarget is off by more than 10%, make an adjustment
  outidx                    <- which(apply(unitSums(stf@harvest[f01,FcY]),2:6,mean,na.rm=T) <  resB |
                                     apply(unitSums(stf@harvest[f01,FcY]),2:6,mean,na.rm=T) >  resB)
  inidx                     <- which(apply(unitSums(stf@harvest[f01,FcY]),2:6,mean,na.rm=T) >= resB &
                                     apply(unitSums(stf@harvest[f01,FcY]),2:6,mean,na.rm=T) <= resB)
  #- If outside this range, do not apply TAC constraint and use 15% cap on F
  if(length(outidx)>0){
    sidx                    <- which((apply(unitSums(stf@harvest[f01,FcY,,,,outidx]),2:6,mean,na.rm=T)) <  resB[outidx])
    bidx                    <- which((apply(unitSums(stf@harvest[f01,FcY,,,,outidx]),2:6,mean,na.rm=T)) >  resB[outidx])

    if(length(sidx)>0) stf@harvest[,FcY,"B",,,outidx[sidx]]       <- sweep(stf@harvest[,FcY,"B",,,outidx[sidx]],2:6,
                                                                      ((resB[outidx[sidx]]) - apply(unitSums(stf@harvest[f01,FcY,c("A","C","D"),,,outidx[sidx]]),2:6,mean,na.rm=T)) /
                                                                        apply(unitSums(stf@harvest[f01,FcY,"B",,,outidx[sidx]]),2:6,mean,na.rm=T),"*")
    if(length(bidx)>0) stf@harvest[,FcY,"B",,,outidx[bidx]]       <- sweep(stf@harvest[,FcY,"B",,,outidx[bidx]],2:6,
                                                                      ((resB[outidx[bidx]]) - apply(unitSums(stf@harvest[f01,FcY,c("A","C","D"),,,outidx[bidx]]),2:6,mean,na.rm=T)) /
                                                                        apply(unitSums(stf@harvest[f01,FcY,"B",,,outidx[bidx]]),2:6,mean,na.rm=T),"*")
  }
  #- Now find the Fs and catches that
  stf@catch[,FcY,"B"]       <- quantSums(stf@catch.wt[,FcY,"B",,,outidx] * stf@stock.n[,FcY,"B",,,outidx] *
                                        (1-exp(-unitSums(stf@harvest[,FcY,,,,outidx])-stf@m[,FcY,"B",,,outidx])) *
                                        (stf@harvest[,FcY,"B",,,outidx]/(unitSums(stf@harvest[,FcY,,,,outidx])+stf@m[,FcY,"B",,,outidx])))

  stf@catch[,FcY,"C"]       <- 0.057*unitSums(stf@catch[,FcY,c("A")])*mixprop + TACS[,FcY,"C"]

   res <- optim(par=rep(1,dims(stf)$unit),find.FABC_F,
                    Fs=stf@harvest[,FcY,,,,iTer,drop=T],
                    Ns=stf@stock.n[,FcY,1,,,iTer,drop=T],
                    Wts=stf@stock.wt[,FcY,1,,,iTer,drop=T],
                    CWts=stf@catch.wt[,FcY,,,,iTer,drop=T],
                    fspwns=stf@harvest.spwn[,FcY,1,,,iTer,drop=T],
                    mspwns=stf@m.spwn[,FcY,1,,,iTer,drop=T],
                    mats=stf@mat[,FcY,1,,,iTer,drop=T],
                    Ms=stf@m[,FcY,1,,,iTer,drop=T],f01=f01,f26=f26,
                    Tcs=iter(TACS[,c(ImY,FcY)],iTer),
                    mixprop=mixprop,
                    FA=resA*1.1,
                    FB=resB,
                    lower=rep(0.01,4),method="L-BFGS-B",control=list(maxit=100))$par

   stf@harvest[,FcY]         <- sweep(stf@harvest[,FcY],c(3,6),res,"*")
   stf@catch[,FcY,"A"]       <- quantSums(stf@catch.wt[,FcY,"A",,,outidx] * stf@stock.n[,FcY,"A",,,outidx] *
                                         (1-exp(-unitSums(stf@harvest[,FcY,,,,outidx])-stf@m[,FcY,"A",,,outidx])) *
                                         (stf@harvest[,FcY,"A",,,outidx]/(unitSums(stf@harvest[,FcY,,,,outidx])+stf@m[,FcY,"A",,,outidx])))
   stf@catch[,FcY,"B"]       <- quantSums(stf@catch.wt[,FcY,"B",,,outidx] * stf@stock.n[,FcY,"B",,,outidx] *
                                         (1-exp(-unitSums(stf@harvest[,FcY,,,,outidx])-stf@m[,FcY,"B",,,outidx])) *
                                         (stf@harvest[,FcY,"B",,,outidx]/(unitSums(stf@harvest[,FcY,,,,outidx])+stf@m[,FcY,"B",,,outidx])))
   stf@catch[,FcY,"C"]       <- (0.057*unitSums(stf@catch[,FcY,c("A")]) + 0.41*advCatchWB) * mixprop



   print(c(apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T),apply(unitSums(stf@harvest[f01,FcY]),2:6,mean,na.rm=T),stf@catch[,FcY,],(0.057*unitSums(stf@catch[,FcY,c("A")]) + 0.41*advCatchWB )* mixprop - stf@catch[,FcY,"C"]))
   stf@harvest[,FcY]         <- fleet.harvest(stk=stf,iYr=FcY,TACS=stf@catch[,FcY])
}
save.image("STFbeforeTransfers.RData")

#load("STFbeforeTransfers.RData")
load("C:/DATA/GIT/HAWG/NSAS/stf/results/STFbeforeTransfers.RData")

# calculate the C fleet TAC
TAC.C <- 0.057 * sum(stf@catch[,FcY,c("A")]) + 0.41 * advCatchWB  #combined C-fleet TAC

# 0% option
TAC.C10 <- TAC.C * 0   #  0% thereof, add to A-fleet as the minimum transfer amount

# 50% option
# TAC.C10 <- TAC.C * 0.5 # 50% thereof, add to A-fleet as the minimum transfer amount

stf@harvest[ac(2:6),,"A"] #fleet A f2-6 before 10% transfer
sum(stf@catch[,FcY,])#total forecasted NSAS outtake before transfer business
stf@catch[,FcY,"A"] * WBSSsplit #WBSS in IV
# 10% C-fleet transfer to the North Sea (C ---> A)
stf@catch[,FcY,"A"] <- stf@catch[,FcY,"A"] + TAC.C10 #- 2953 #add 10% C-fleet TAC to A-fleet (and don't transfer WBSS proportion in A-fleet back to C-fleet!!)
stf@catch[,FcY,"C"] <- stf@catch[,FcY,"C"] - (TAC.C10 * mixprop) #remove 10% from the C-fleet (this time, only NSAS using mixing proportion)
sum(stf@catch[,FcY,]) #new total NSAS outtake
stf@harvest[,FcY]         <- fleet.harvest(stk=stf,iYr=FcY,TACS=stf@catch[,FcY]) # recalculate new F's for all fleets after transferring
stf@harvest[ac(2:6),,"A"] #new partial F for the A-fleet

apply(unitSums(stf@harvest[f26,FcY]),2:6,mean,na.rm=T) # new F-bar (F2-6) of all fleets for NSAS

##fill stf.table
stf.table["mp","Fbar 2-6 A",]                                  <- iterQuantile(quantMeans(stf@harvest[f26,FcY,"A"]))
stf.table["mp",grep("Fbar 0-1 ",dimnames(stf.table)$values),]  <- aperm(iterQuantile(quantMeans(stf@harvest[f01,FcY,c("B","C","D")])),c(2:6,1))
stf.table["mp","Fbar 2-6",]                                    <- iterQuantile(quantMeans(unitSums(stf@harvest[f26,FcY,])))
stf.table["mp","Fbar 0-1",]                                    <- iterQuantile(quantMeans(unitSums(stf@harvest[f01,FcY,])))
stf.table["mp",grep("Catch ",dimnames(stf.table)$values),]     <- aperm(iterQuantile(harvestCatch(stf,FcY)),c(2:6,1))
stf.table["mp",grep("SSB",dimnames(stf.table)$values)[1],]     <- 
  iterQuantile(quantSums(stf@stock.n[,FcY,1] * stf@stock.wt[,FcY,1] * 
                           exp(-unitSums(stf@harvest[,FcY])*
                                 stf@harvest.spwn[,FcY,1]-stf@m[,FcY,1]*stf@m.spwn[,FcY,1]) * 
                           stf@mat[,FcY,1]))

