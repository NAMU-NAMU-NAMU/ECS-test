# PHP 8.2 + Apache ベースイメージ
FROM php:8.2-apache

# システムの更新と必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    curl \
    zip \
    unzip \
    git \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# 必要なPHP拡張をインストール
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip

# Apacheのmod_rewriteを有効化（Laravel用）
RUN a2enmod rewrite

# Node.js 18をインストール（npm用）
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Composerをインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 作業ディレクトリ設定
WORKDIR /var/www/html

# まずcomposer.jsonとpackage.jsonをコピー（キャッシュ効率化）
COPY composer.json composer.lock package.json package-lock.json ./

# Composer依存関係インストール（本番環境用）
RUN composer install --no-dev --no-scripts --no-autoloader --optimize-autoloader

# npmパッケージインストール
RUN npm ci --only=production

# アプリケーションコードをコピー
COPY . .

# Composer autoloaderを再生成
RUN composer dump-autoload --no-dev --optimize

# npmビルドを実行
RUN npm run production

# 環境ファイルの設定（本番では環境変数を使用推奨）
RUN cp .env.example .env || echo "APP_ENV=production" > .env

# Laravel用の設定とキャッシュクリア
RUN php artisan key:generate \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# パーミッション設定
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Apache設定：DocumentRootをpublicディレクトリに変更
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Apache設定の最適化
RUN echo '<Directory /var/www/html/public>\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/apache2.conf

# 不要なファイルの削除
RUN rm -rf /var/www/html/node_modules \
    && rm -rf /var/www/html/.git \
    && rm -rf /var/www/html/tests

# ポート80を開放
EXPOSE 80

# Apacheをフォアグラウンドで起動
CMD ["apache2-foreground"]
