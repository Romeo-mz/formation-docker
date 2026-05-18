# TP easy_deploy — Dockerfile volontairement simple pour commencer.
# À améliorer pendant le TP : cache des layers, stage dev/final, gunicorn, taille finale.

# TODO formation : choisissez une image de base Python. Quelle variante est la plus légère ?

# curl est requis pour le healthcheck HTTP défini dans docker-compose.yml
RUN apk add --no-cache curl

# WORKDIR /usr/local/app

# COPY 
# RUN 
COPY . .

# EXPOSE 

# TODO formation : remplacer le serveur Flask dev par gunicorn dans un stage final.
CMD ["python", "app.py"]
