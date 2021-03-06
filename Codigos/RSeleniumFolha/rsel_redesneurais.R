setwd("~/Pesquisa/Machine/SIT")
source("funcoes.R")
library(stringr)
load("redeneural.RData")
library("RSelenium")
cota <- read.table("bovespa")



comp <- vector()
venda <- vector()


for(i in cota[,1]){
  f <- i
  ti <- paste0(i,".SA")
  tickers = ti
  print(ti)
  
  precos = new.env()
  getSymbols(tickers, src = 'yahoo', from = '2017-01-01', to = '2018-12-31',
             env = precos, auto.assign = T)
  
  #Ajustando os valores
  
  for(i in ls(precos)) precos[[i]] = adjustOHLC(precos[[i]], use.Adjusted=T)  
  bt.prep(precos, align='remove.na') 
  
  prices = precos$prices  
  models = list()
  
  dadostreino <-  cbind(prices,EMA(prices, 8), EMA(prices, 17),EMA(prices, 34),
                        RSI(prices,17),stoch(prices,8), MACD(prices, 12,26,9))
  
  redesn <- compute(rede, dadostreino)
  
  arvore <- cbind(iif(prices > SMA(prices, 20), 1, 0),
                  iif(cross.up(SMA(prices, 8), SMA(prices, 20)), 1, 0),
                  iif(50 > RSI(prices, 16), 1, 0),
                  iif(prices < redesn$net.result, 1, 0))
  
  x <- as.data.frame(apply(arvore,1, sum)/ncol(arvore))
 
  precos$weight <- iif(x >= 0.5, 1, 0)
  
  if(last(precos$weight) == 1 & precos$weight[(nrow(precos$weight)-1),] == 0){
    comp <- c(comp, f)
    
  }
  
  if(last(precos$weight) == 0 & precos$weight[(nrow(precos$weight)-1),] == 1){
    
    venda <-  c(venda, f)
  }
}


#------------------------------------------------------------------------------------------
#Logando no Folha Invest
rD <- rsDriver(browser = "firefox")
remDr <- rD[["client"]]
remDr$navigate("https://login.folha.com.br/login?done=http%3A%2F%2Ffolhainvest.folha.uol.com.br%2Fcarteira&service=folhainvest")

login <- remDr$findElement("name", "email")
login$sendKeysToElement(list("guilhermehathy@hotmail.com"))
senha <- remDr$findElement("name", "password")
senha$sendKeysToElement(list("9895iyij", key = "enter"))

Sys.sleep(10)


lim <- remDr$findElement(using = 'xpath', 
                         paste0("//div[@id='userInfo']/p[5]"))
limite <- lim$getElementText()

limite <- as.character(limite)
limite <- strsplit(limite, " ")
limite <- strsplit(limite[[1]], ",")
limite <- limite[[6]][1]
g <- (as.numeric(limite))*1000
c <- len(comp)
y <- g/c
y



#----------------------------------------------------------------------------------------

for(i in venda){
  remDr <- rD[["client"]]
  remDr$navigate("http://folhainvest.folha.uol.com.br/vender")
  
  
  #A Ação
  option <- remDr$findElement(using = 'xpath', 
                              paste0("//option[@value='", i,"']"))
  option$clickElement()
  
  #Preço a mercado
  amercado <- remDr$findElement(using = 'id',"pricing_market")
  amercado$clickElement()
  
  #Selecionando a quantidade
  
  quantidade <- remDr$findElement(using = 'xpath', 
                                  paste0("//span[@id='sellStockNum']"))
  quant <- quantidade$getElementText()
  quantidade$sendKeysToElement(list(paste0(quant), key = "enter"))
  
  Sys.sleep(10)
  
  #Confirmando Ordem
  
  confirma <- remDr$findElement(using = 'name',"confirm")
  confirma$clickElement()
}


#-----------------------------------------------------------------------------------------

for(i in comp){
  remDr <- rD[["client"]]
  remDr$navigate("http://folhainvest.folha.uol.com.br/comprar")
  
  #A Ação
  option <- remDr$findElement(using = 'xpath', 
                              paste0("//option[@value='", i,"']"))
  option$clickElement()
  
  #Preço a mercado
  amercado <- remDr$findElement(using = 'id',"pricing_market")
  amercado$clickElement()
  
  #Selecionando a quantidade
  quantidade <- remDr$findElement("name", "quantity")
  quant <- round(y/ultimopreco(i), 0)
  quantidade$sendKeysToElement(list(paste0(quant), key = "enter"))
  
  Sys.sleep(10)
  
  #Confirmando Ordem
  
  confirma <- remDr$findElement(using = 'name',"confirm")
  confirma$clickElement()
  
}


