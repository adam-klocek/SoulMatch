FROM rocker/shiny:4.4.3
RUN apt-get update && apt-get install -y --no-install-recommends libsodium-dev libpng-dev libjpeg-dev libsqlite3-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /srv/shiny-server/soulmatch
COPY . .
RUN Rscript scripts/install.R && Rscript scripts/test.R && chown -R shiny:shiny /srv/shiny-server/soulmatch
USER shiny
ENV SOULMATCH_DEMO_MODE=false SOULMATCH_DATA_DIR=/srv/shiny-server/soulmatch/data
EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('.', host='0.0.0.0', port=3838)"]
