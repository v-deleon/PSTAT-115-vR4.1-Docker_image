ARG BASE_IMAGE=jupyter/r-notebook:r-4.1.0
FROM $BASE_IMAGE

USER root

ENV PATH=$PATH:/usr/lib/rstudio-server/bin \
    R_HOME=/opt/conda/lib/R \
    RSESSION_PROXY_RSTUDIO_1_4=yes
ARG LITTLER=$R_HOME/library/littler

RUN \
    # download R studio
    curl --silent -L --fail https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.4.1717-amd64.deb > /tmp/rstudio.deb && \
    echo '7a125b0715ee38e00e5732fd3306ce15 /tmp/rstudio.deb' | md5sum -c - && \
    \
    # install R studio
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    \
    # setting default CRAN mirror
    echo -e "local({ \n" \
         "   r <- getOption('repos')\n" \
         "   r['CRAN'] <- 'https://cloud.r-project.org'\n" \
         "   options(repos = r)\n" \
         "})\n" > $R_HOME/etc/Rprofile.site && \
    \
    # littler provides install2.r script
    R -e "install.packages(c('littler', 'docopt'))" && \
    \
    # modifying littler scripts to conda R location
    sed -i 's/\/usr\/local\/lib\/R\/site-library/\/opt\/conda\/lib\/R\/library/g' \
        ${LITTLER}/examples/*.r && \
	ln -s ${LITTLER}/bin/r ${LITTLER}/examples/*.r /usr/local/bin/ && \
	echo "$R_HOME/lib" | sudo tee -a /etc/ld.so.conf.d/littler.conf && \
	ldconfig
    
USER $NB_USER

RUN pip install nbgitpuller okpy && \
    pip install git+https://github.com/okpy/jassign.git && \
    pip install jupyter-server-proxy jupyter-rsession-proxy 
USER $NB_USER

# REmoving some packages that are probably duplicated
#RUN R -e "install.packages(c('r-sf', 'r-units', 'r-stan', 'udunits2', 'majick', 'tidylog', 'tidytuesdayR', 'janitor', 'readxl', 'lubridate', 'lucid', 'magrittr', 'learnr', 'haven', 'summarytools', 'ggplot2', 'kableExtra', 'flextable', 'sandwich', 'sf', 'stargazer', 'viridis', 'titanic', 'labelled', 'Lahman', 'babynames', 'nasaweather', 'fueleconomy', 'mapproj', 'forcats', 'rvest', 'readxl', 'quantmod', 'polite', 'pdftools', 'ncfd4', 'modelsummary', 'maps', 'magritter', 'lubridate', 'lmtest', 'knitr', 'anytime', 'broom', 'devtools', 'fixest', 'ggmap', 'ggplot2', 'ggthemes', 'httr', 'janitor', 'jsonlite', 'kableExtra'), repos = 'http://cran.us.r-project.org')"

#RUN R --quiet -e "devtools::install_github('UrbanInstitute/urbnmapr', dep=FALSE)"
#RUN R --quiet -e "devtools::install_github('rapporter/pander')"
# Part of PSTAT-115
USER root

## Required rstan build method to work with docker and kubernetes (Beginning)
#-- RSTAN
#-- install rstan reqs
RUN R -e "install.packages(c('inline','gridExtra','loo'))"
#-- install rstan
RUN R -e "dotR <- file.path(Sys.getenv('HOME'), '.R'); if(!file.exists(dotR)){ dir.create(dotR) }; Makevars <- file.path(dotR, 'Makevars'); if (!file.exists(Makevars)){  file.create(Makevars) }; cat('\nCXX14FLAGS=-O3 -fPIC -Wno-unused-variable -Wno-unused-function', 'CXX14 = g++ -std=c++1y -fPIC', file = Makevars, sep = '\n', append = TRUE)"
RUN R -e "install.packages(c('ggplot2','StanHeaders'))"
RUN R -e "packageurl <- 'http://cran.r-project.org/src/contrib/Archive/rstan/rstan_2.19.3.tar.gz'; install.packages(packageurl, repos = NULL, type = 'source')"
#-- Docker Makevars substitute (Allows for clearing of Home directory during persistance storage build)
RUN sed -i 's/CXX14 = /CXX14 = g++ -std=c++1y -fPIC/I' $R_HOME/etc/Makeconf && \
    sed -i 's/CXX14FLAGS = /CXX14FLAGS = -O3 -fPIC -Wno-unused-variable -Wno-unused-function/I' $R_HOME/etc/Makeconf
## Required rstan build (End)

#-- ggplot2 extensions
RUN R -e "install.packages(c('GGally','ggridges','viridis'))"

#-- Misc utilities
RUN R -e "install.packages(c('beepr','config','tinytex','rmarkdown','formattable','here','Hmisc'))"

RUN R -e "install.packages(c('kableExtra','logging','microbenchmark','openxlsx'))"

RUN R -e "install.packages(c('RPushbullet','styler','ggridges','plotmo'))"

RUN R -e "install.packages(c('nloptr'))"

RUN R --vanilla -e "install.packages('minqa',repos='https://cloud.r-project.org', dependencies=TRUE)"

#-- Caret and some ML packages
#-- ML framework, metrics and Models
RUN R -e "install.packages(c('codetools'))"
RUN R --vanilla -e "install.packages('caret',repos='https://cloud.r-project.org')"
RUN R -e "install.packages(c('car','ensembleR','MLmetrics','pROC','ROCR','Rtsne','NbClust'))"

RUN apt-get update && apt-get install -y \
    nano && \
    apt-get clean && rm -rf /var/lib/lists/*

RUN R -e "install.packages(c('tree','maptree','arm','e1071','elasticnet','fitdistrplus','gam','gamlss','glmnet','lme4','ltm','randomForest','rpart','ISLR'))"

#-- More Bayes stuff
RUN R -e "install.packages(c('coda','projpred','MCMCpack','hflights','HDInterval','tidytext','dendextend','LearnBayes'))"

RUN R -e "install.packages(c('rstantools', 'shinystan'))"

RUN R -e "install.packages(c('mvtnorm','dagitty','tidyverse','codetools'))"

RUN R -e "devtools::install_github('rmcelreath/rethinking', upgrade = c('never'))"

#-- Cairo
#-- Cairo Requirements
RUN apt-get update && apt-get install -y \
    libpixman-1-dev \
    libcairo2-dev \
    libxt-dev && \
    apt-get clean && rm -rf /var/lib/lists/*
RUN R -e "install.packages(c('Cairo'))"

# Removes the .R folder for accurate simulation of Kubernetes/Docker/Persistant storage env
RUN rm -R $HOME/.R

USER $NB_USER
# remove cache
RUN rm -rf ~/.cache/pip ~/.cache/matplotlib ~/.cache/yarn && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER 
