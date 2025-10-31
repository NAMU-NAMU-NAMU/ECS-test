# PHP 8.2 + Apache ベースイメージ
FROM php:8.2-apache

# 必要なPHP拡張をインストール
RUN docker-php-ext-install pdo pdo_mysql mysqli

# Apacheのmod_rewriteを有効化（Laravel用）
RUN a2enmod rewrite

# Node.js 18をインストール（npm用）
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update && apt-get install -y nodejs zip unzip git

# Composerをインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 作業ディレクトリ設定
WORKDIR /var/www/html

# アプリケーションコードをコピー
COPY . .

# 環境ファイルのサンプルをコピー（本番では適切に設定）
COPY .env.example .env

# Composer依存関係インストール（本番環境用）
RUN composer install --no-dev --optimize-autoloader

# npmパッケージインストールとビルド
RUN npm install && npm run production

# Laravel用の設定
RUN php artisan key:generate
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache

# パーミッション設定
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
RUN chmod -R 755 /var/www/html/storage

# Apache設定：DocumentRootをpublicディレクトリに変更
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# ポート80を開放
EXPOSE 80

# Apacheをフォアグラウンドで起動
CMD ["apache2-foreground"]
