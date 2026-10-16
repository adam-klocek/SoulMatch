library(shiny)
library(psych)

shinyServer(function(input, output, session) {
  #input$button
  
  rel <- c(men=0.9268443, women = 0.9478245)        ## reliabilita (r_xx')
  validity <- c(men=0.8643642, women=0.8895554)     ## validita (r_xy)
  quant <- qnorm(.975)                              ## kvantil pro 95% CI
  norms <- cbind(cm = c(men=182.09, women=167.95),  ## deskriptivy
                 cm.sd = c(7.56, 7.03),
                 dot = c(20.02, 14.30),
                 dot.sd = c(6.28, 7.41))
  
  dotaznik <- eventReactive(input$button, { ## observed score computation
     
    vyska.dot <- 6*3 + as.numeric(input$p1) + as.numeric(input$p2) + as.numeric(input$p3) + 
      as.numeric(input$p4) + as.numeric(input$p5) - 
      (as.numeric(input$p6) + as.numeric(input$p7) + as.numeric(input$p8) + 
         as.numeric(input$p9) + as.numeric(input$p10) + as.numeric(input$p11))
    vyska.dot
  })

  se <- eventReactive(input$button, {
    if (input$sex == 0) {
      se <- norms[1, 4] * sqrt(1-rel[1])## standard error of measurement
      se.pred <- norms[1, 2] * sqrt(1-validity[1]**2) ## standard error of prediction
      vyska.exp <- dotaznik() * rel[1] + norms[1, 3] * (1-rel[1]) ## expected true score
      vyska.cm <- 161.22621 + 1.04240*dotaznik() ## expected height in cm
      dot.ci <- vyska.exp + c(-1, 1)*quant*se   ## CI for questionnaire
      cm.ci <- vyska.cm + c(-1,1)*quant*se.pred ## CI for height prediction
      iq <- (c(dotaznik(), dot.ci) - norms[1, 3])/norms[1, 4]*15 + 100 ## IQ score + CI of measurement
      iq.cm <- c(iq[1], (cm.ci-norms[1, 1])/norms[1, 2]*15 + 100)      ## IQ score + CI of prediction
    } else {
      se <- norms[2, 4] * sqrt(1-rel[2])## standard error of measurement
      se.pred <- norms[2, 2] * sqrt(1-validity[2]**2) ## standard error of prediction
      vyska.exp <- dotaznik() * rel[2] + norms[2, 3] * (1-rel[2]) ## expected true score
      vyska.cm <- 155.8392013 + 0.8456295*dotaznik() ## expected height in cm
      dot.ci <- vyska.exp + c(-1, 1)*quant*se   ## CI for questionnaire
      cm.ci <- vyska.cm + c(-1,1)*quant*se.pred ## CI for height prediction
      iq <- (c(dotaznik(), dot.ci) - norms[2, 3])/norms[2, 4]*15 + 100 ## IQ score + CI of measurement
      iq.cm <- c(iq[1], (cm.ci-norms[2, 1])/norms[2, 2]*15 + 100)      ## IQ score + CI of prediction
    }

    
    list(se=se, se.pred=se.pred, vyska.exp=vyska.exp, vyska.cm=vyska.cm, dot.ci=dot.ci, cm.ci=cm.ci, 
         iq=iq, iq.cm=iq.cm)
  })
  
  output$iq <- renderText({
    input$button
    paste0("V dotazníku výšky máte hrubé skóre ", 
           dotaznik(), 
           " , což odpovídá vaší psychologické výšce měřené výškovým kvocientem (IQ) ", 
           round(se()$iq[1]),
           " IQ s 95% intervalem spolehlivosti [",
           round(se()$iq[2]),
           "-",
           round(se()$iq[3]),
           "]. ")
  })
  output$vyska <- renderText({
    input$button
    paste0("Vaše tělesná výška, vyjádřená rovněž výškovým kvocientem, je nejpravděpodobněji taktéž ",
           round(se()$iq.cm[1]),
           ", avšak s o něco širším 95% intervalem spolehlivosti [",
           round(se()$iq.cm[2]),
           "-",
           round(se()$iq.cm[3]),
           "].")
  })
  output$cm <- renderText({
    input$button
    paste0("Po přepočtení lze nicméně vaši tělesnou výšku odhadnout na ",
           round(se()$vyska.cm),
           " cm s 95% intervalem spolehlivosti [",
           round(se()$cm.ci[1]),
           "-",
           round(se()$cm.ci[2]),
           "] centimetrů.")
  })
  normy <- eventReactive(input$button,{
    # norms <- as.data.frame(norms)
    normy <- data.frame(N=as.character(c(1479, 3406)), norms)
    rownames(normy) <- c("muži", "ženy")
    colnames(normy) <- c("N", "M (cm)", "SD (cm)", "M (dotazník)", "SD (dotazník")
    as.data.frame(normy)
  })
  output$normy <- renderTable(normy(), align = "c", rownames = T)

  
  
  # output$vyska.dot <- renderText({
  #   input$button
  #   dotaznik()
  # })
  # output$iq <- renderText({
  #   input$button
  #   dotaznik()
  # })
  
  # output$gauss <- renderPlot({
  #   if (input$type == "iq") {
  #     x <- seq(40, 160, by=.01)
  #     y <- dnorm(x, 100, 15)
  #     if (staff()[1] < 50) {
  #       by.par <- -.01
  #     } else {
  #       by.par <- .01
  #     }
  #     x2 <- seq(50, staff()[1], by=by.par)
  #     plot(x, y, type="l", lwd=3, col="darkblue", main="Gauss curve", xlab="intelligence scale (IQ)", ylab="", yaxt="ny")
  #     polygon(c(x[x <= staff()[1]], staff()[1]), c(y[x <= staff()[1]], 0), col="lightblue", border=NA)
  #     lines(x, y, lwd=3, col="darkblue")
  #     abline(v=staff()[1], lwd=3, col="red")
  #     text(staff()[1]+1, y=.005, labels = paste("Your IQ =", staff()[1]), pos=4, srt=90)
  #   } else {
  #     x <- seq(140, 210, by=.01)
  #     if (input$sex == "man") {
  #       M <- 180
  #       SD <- 7
  #     } else {
  #       M <- 167
  #       SD <- 6.1
  #     }
  #     y <- dnorm(x, M, SD)
  #     plot(x, y, type="l", lwd=3, col="darkblue", main="Gauss curve", xlab="height scale (cm)", ylab="", yaxt="ny")
  #     polygon(c(x[x <= staff()[2]], staff()[2]), c(y[x <= staff()[2]], 0), col="lightblue", border=NA)
  #     lines(x, y, lwd=3, col="darkblue")
  #     abline(v=staff()[2], lwd=3, col="red")
  #     text(staff()[2]+1, y=.005, labels = paste("Your height =", round(staff()[2], 0), "cm"), pos=4, srt=90)
  #   }
  # })
})