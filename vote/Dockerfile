# TP easy_deploy — Dockerfile volontairement simple pour commencer.
# À améliorer pendant le TP : cache des layers, stage dev/final, gunicorn, taille finale.

FROM python:3.13

RUN apk add --no-cache curl

# WORKDIR /usr/local/app

# COPY 
# RUN 
COPY . .

# EXPOSE 

# TODO formation : remplacer le serveur Flask dev par gunicorn dans un stage final.
CMD ["python", "app.py"]
