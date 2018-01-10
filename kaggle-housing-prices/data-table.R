###################################################################
#### References                                                ####
###################################################################
##http://www.listendata.com/2016/10/r-data-table.html
##http://brooksandrew.github.io/simpleblog/articles/advanced-data-table/
##http://www.cookbook-r.com/Manipulating_data/Changing_the_order_of_levels_of_a_factor/
###################################################################
#### Dependencies                                              ####
###################################################################
require(data.table) # fast data wrangling and analysis
require(psych)      # descriptive statistics, skewness and kurtosis
require(caret)      # (near) zero variance
###################################################################
#### Syntax description                                        ####
###################################################################
## The general form of data.table syntax is:
##  DT[ i,  j,  by ] # + extra arguments
##      |   |   |
##      |   |    -------> grouped by what?
##      |    -------> what to do?
##       ---> on which rows?
###################################################################
#### Get data                                                  ####
###################################################################
train.dt <- fread(input = "train.csv", 
                  sep = ",", 
                  nrows = -1,
                  header = T,
                  na.strings=c("NA","N/A","null"),
                  stringsAsFactors = F,
                  check.names = T,
                  strip.white = T,
                  blank.lines.skip = T,
                  data.table = T
) 
test.dt <- fread(input = "test.csv", 
                 sep = ",", 
                 nrows = -1,
                 header = T,
                 na.strings=c("NA","N/A","null"),
                 stringsAsFactors = F,
                 check.names = T,
                 strip.white = T,
                 blank.lines.skip = T,
                 data.table = T
) 
## Create one data set for feature engineering. 
train.dt[, dataPartition:="train"]
test.dt[, SalePrice:=as.integer(NA)] 
test.dt[, dataPartition:="test"]
full.dt <- rbindlist(list(train.dt, test.dt), use.names = F, fill = F)
###################################################################
#### Data dictionary                                           ####
###################################################################
## Data types
variableTypes.df <- cbind(as.data.frame(names(full.dt)),as.data.frame(sapply(full.dt, class)))
names(variableTypes.df) <- c("variable","type")
## Numeric, square footage
variablesSquareFootage <- c(
  "LotFrontage", 		## Linear feet of street connected to property 
  "LotArea",    		## Lot size in square feet
  "MasVnrArea",  		## Masonry veneer area in square feet
  "BsmtFinSF1",		  ## Type 1 finished square feet	
  "BsmtFinSF2",		  ## Type 2 finished square feet
  "BsmtUnfSF",		  ## Unfinished square feet of basement area
  "TotalBsmtSF", 		## Total square feet of basement area
  "FirstFlrSF",		  ## First Floor square feet
  "SecondFlrSF",	  ## Second floor square feet
  "LowQualFinSF", 	## Low quality finished square feet (all floors)
  "GrLivArea", 		  ## Above grade (ground) living area square feet
  "GarageArea",     ## Size of garage in square feet
  "WoodDeckSF",     ## Wood deck area in square feet
  "OpenPorchSF",    ## Open porch area in square feet  
  "EnclosedPorch",  ## Enclosed porch area in square feet 
  "ThreeSsnPorch",  ## Three season porch area in square feet 
  "ScreenPorch",    ## Screen porch area in square feet
  "PoolArea" 		    ## Pool area in square feet
)
## Counts, a house has n of something
variablesCounts <- c(
  "BsmtFullBath",		## Basement full bathrooms
  "BsmtHalfBath",		## Basement half bathrooms
  "FullBath",			  ## Full bathrooms above grade
  "HalfBath",			  ## Half baths above grade
  "BedroomAbvGr",		## Bedrooms above grade (does NOT include basement bedrooms)
  "KitchenAbvGr",		## Kitchens above grade
  "TotRmsAbvGrd",		## Total rooms above grade (does not include bathrooms)
  "Fireplaces",		  ## Number of fireplaces
  "GarageCars"     	## Size of garage in car capacity
)
## Values
variablesValues <- c(
  "MiscVal",        ## $ Value of miscellaneous feature
  "SalePrice"       ## $ Price paid
)
## Factors
variablesFactor <- colnames(full.dt)[which(as.vector(full.dt[,sapply(full.dt, class)]) == "character")]
variablesFactor <- c(variablesFactor,
                     "MSSubClass",     ## Identifies the type of dwelling involved in the sale
                     "OverallQual",    ## Rates the overall material and finish of the house
                     "OverallCond",     ## Rates the overall condition of the house
                     ## Import year and months as integers.
                     #"MoSold",           
                     "YrSold",        
                     "YearRemodAdd"   
                     #"YearBuilt",     
                     #"GarageYrBlt"    
)
# <- sapply(names(full.dt),function(x){class(full.dt[[x]])})
# <-names(feature_classes[feature_classes != "character"])
###################################################################
#### Data engineering                                          ####
###################################################################
## In R first character can not be a number in variable names
setnames(full.dt, c("X1stFlrSF","X2ndFlrSF","X3SsnPorch"), c("FirstFlrSF","SecondFlrSF","ThreeSsnPorch"))
## Set columns to numeric
changeColType <- c(variablesSquareFootage, variablesCounts, variablesValues)
full.dt[,(changeColType):= lapply(.SD, as.numeric), .SDcols = changeColType]
## Set columns to factor
changeColType <- variablesFactor
full.dt[,(changeColType):= lapply(.SD, as.factor), .SDcols = changeColType]
###################################################################
#### Ordered factors                                           ####
###################################################################
## OverallQual, rates the overall material and finish of the house
full.dt[,OverallQual:=ordered(OverallQual, levels = c(1:10))]
## OverallCond, rates the overall condition of the house
full.dt[,OverallCond:=ordered(OverallCond, levels = c(1:10))]
## KitchenQual, kitchen quality
full.dt[,KitchenQual:=ordered(KitchenQual, levels = c("Po","Fa","TA","Gd","Ex"))]
## GarageFinish (contains NA's)
full.dt[,GarageFinish:=ordered(GarageFinish, levels = c("None","Unf","RFn","Fin"))]
## ExterQual, evaluates the quality of the material on the exterior  
full.dt[,ExterQual:=ordered(ExterQual, levels = c("Po","Fa","TA","Gd","Ex"))]
## ExterCond, evaluates the present condition of the material on the exterior
full.dt[,ExterCond:=ordered(ExterCond, levels = c("Po","Fa","TA","Gd","Ex"))]
## BsmtQual (contains NA's), evaluates the height of the basement
full.dt[,BsmtQual:=ordered(BsmtQual, levels = c("None","Po","Fa","TA","Gd","Ex"))]
## BsmtCond (contains NA's), evaluates the general condition of the basement
full.dt[,BsmtCond:=ordered(BsmtCond, levels = c("None","Po","Fa","TA","Gd","Ex"))]
## BsmtExposure (contains NA's), refers to walkout or garden level walls
full.dt[,BsmtExposure:=ordered(BsmtExposure, levels = c("None","No","Mn","Av","Gd"))]
## BsmtFinType1 (contains NA's), rating of basement finished area
full.dt[,BsmtFinType1:=ordered(BsmtFinType1, levels = c("None","Unf","LwQ","Rec","BLQ","ALQ","GLQ"))]
## FireplaceQu (contains NA's), fireplace quality
full.dt[,FireplaceQu:=ordered(FireplaceQu, levels = c("None","Po","Fa","TA","Gd","Ex"))]
## Electrical
full.dt[,Electrical:=ordered(Electrical, levels = c("FuseP","Mix","FuseF","FuseA","SBrkr"))]
## Did not (yet) convert all possible factors to hierarchical.
## Ordered factors are not supported by h2o, Let's convert them into integers during pre-processing. Lowest level will be 1 etc.
###################################################################
#### Descriptive statistics                                    ####
###################################################################
## statisticts
descStats.df <- describe(full.dt[, c(variablesSquareFootage,variablesValues), with = FALSE]) ## from psych package 
print(descStats.df)
## na values
countIsNA <- sapply(full.dt,function(x)sum(is.na(x)))
countIsNA.df <- data.frame(countIsNA)
countIsNA.df <- data.frame(variableName = row.names(countIsNA.df), countIsNA.df,row.names = NULL)
countIsNA.df <- countIsNA.df[countIsNA >0,]
print(countIsNA.df)
## zero variance
zeroVarianceVariables.df <- nearZeroVar(full.dt, names = T, saveMetrics = T,
                                        foreach = T, allowParallel = T)
###################################################################
#### Impute missing values                                     ####
###################################################################
## Kitchen
full.dt[is.na(KitchenQual), KitchenQual := "TA" ] ## One record, set to Typical
## Garage
full.dt[is.na(GarageFinish) & GarageType == "Detchd", ':=' (GarageFinish = "Fin",
                                                        GarageCars = 1,
                                                        GarageArea = 360,
                                                        GarageYrBlt = YearRemodAdd,
                                                        GarageQual = "TA",
                                                        GarageCond = "TA")] 
full.dt[is.na(GarageFinish), GarageFinish := "None"]
full.dt[is.na(GarageQual), GarageQual := "None"]
full.dt[is.na(GarageCond), GarageCond := "None"]
full.dt[is.na(GarageType), GarageType := "None"]
full.dt[is.na(GarageYrBlt), GarageYrBlt := 0]
## Basement
full.dt[is.na(BsmtExposure) & BsmtFinType1 == "Unf" , BsmtExposure := "No"]
full.dt[is.na(BsmtExposure), BsmtExposure := "None"]
full.dt[is.na(BsmtQual) & BsmtFinType1 == "Unf" , BsmtQual := "TA"]
full.dt[is.na(BsmtQual), BsmtQual := "None"]
full.dt[is.na(BsmtCond), BsmtCond := "None"]
full.dt[is.na(BsmtFinType1), BsmtFinType1 := "None"]
full.dt[is.na(BsmtFinType2) & BsmtFinSF2 > 0, BsmtFinType2 := "Unf"]
full.dt[is.na(BsmtFinType2), BsmtFinType2 := "None"]
full.dt[is.na(BsmtFinSF1),':=' (BsmtFinSF1 = 0, BsmtFinSF2 = 0, BsmtUnfSF = 0, TotalBsmtSF = 0)] 
full.dt[is.na(BsmtFullBath),':=' (BsmtFullBath = 0, BsmtHalfBath = 0)] 
## FireplaceQu  
full.dt[is.na(FireplaceQu), FireplaceQu := "None"]
## LotFrontage
full.dt[, LotFrontage := replace(LotFrontage, is.na(LotFrontage), median(LotFrontage, na.rm=TRUE)), by=.(Neighborhood)]
## MSZoning
## RL for missing MSZoning in Mitchel because GrLivArea is greater then max of RM
## Not sure (yet) for missing MSZoning in IDOTRR. RM is most common in IDOTRR but might be wrong
full.dt[is.na(MSZoning) & Neighborhood == "Mitchel", MSZoning := "RL"]
full.dt[is.na(MSZoning) & Neighborhood == "IDOTRR", MSZoning  := "RM"]
## Electrical
## Most common value for neighborhood Timber is SBrkr
full.dt[is.na(Electrical) , Electrical  := "SBrkr"]
## Exterior
## Most common for neighborhood and large total square footage is "MetalSd"
full.dt[is.na(Exterior1st),':=' (Exterior1st = "MetalSd",Exterior2nd = "MetalSd")]
## MasVnrType and MasVnrArea. Taking the easy way out here
full.dt[is.na(MasVnrType),':=' (MasVnrType = "None", MasVnrArea = 0)]
## SaleType
full.dt[is.na(SaleType), SaleType := "WD"]
## Functional
full.dt[is.na(Functional), Functional := "Typ"]
## MiscFeature
full.dt[is.na(MiscFeature), MiscFeature := "None"]
###################################################################
#### Feature engineering                                       ####
###################################################################
## Total square footage porche
full.dt[,porchTotalSF := (OpenPorchSF + EnclosedPorch + ThreeSsnPorch + ScreenPorch)]
## Total square footage
full.dt[,totalSF := (TotalBsmtSF + FirstFlrSF + SecondFlrSF)]
## Update variablesSquareFootage
variablesSquareFootage <- c(variablesSquareFootage,"totalSF", "porchTotalSF")
###################################################################
#### Removed                                                   ####
###################################################################
## no variance 
full.dt[, Utilities  := NULL] ## just one record with none


