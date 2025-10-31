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

# アプリケーションコードを先にコピー
COPY . .

# composer.jsonが存在する場合のみComposer依存関係インストール
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    else \
        echo "composer.json not found, skipping composer install"; \
    fi

# package.jsonが存在する場合のみnpmパッケージインストール
RUN if [ -f "package.json" ]; then \
        if [ -f "package-lock.json" ]; then \
            npm ci --only=production; \
        else \
            npm install --only=production; \
        fi; \
        npm run production; \
    else \
        echo "package.json not found, skipping npm install"; \
    fi

# .envファイルの作成（基本的な設定）
RUN if [ ! -f ".env" ]; then \
        echo "APP_NAME=Laravel" > .env && \
        echo "APP_ENV=production" >> .env && \
        echo "APP_KEY=" >> .env && \
        echo "APP_DEBUG=false" >> .env && \
        echo "APP_URL=http://localhost" >> .env && \
        echo "LOG_CHANNEL=stack" >> .env; \
    fi

# Laravel用の設定（.envが存在する場合のみ）
RUN if [ -f "artisan" ]; then \
        php artisan key:generate --no-interaction; \
        php artisan config:cache; \
        php artisan route:cache || echo "Route cache failed, continuing..."; \
        php artisan view:cache || echo "View cache failed, continuing..."; \
    else \
        echo "artisan not found, skipping Laravel commands"; \
    fi

# パーミッション設定（ディレクトリが存在する場合のみ）
RUN chown -R www-data:www-data /var/www/html && \
    if [ -d "storage" ]; then chmod -R 755 storage; fi && \
    if [ -d "bootstrap/cache" ]; then chmod -R 755 bootstrap/cache; fi

# Apache設定：DocumentRootをpublicディレクトリに変更（publicが存在する場合のみ）
RUN if [ -d "public" ]; then \
        sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf && \
        sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
        echo '<Directory /var/www/html/public>' >> /etc/apache2/apache2.conf && \
        echo '    AllowOverride All' >> /etc/apache2/apache2.conf && \
        echo '    Require all granted' >> /etc/apache2/apache2.conf && \
        echo '</Directory>' >> /etc/apache2/apache2.conf; \
    else \
        echo "public directory not found, using default DocumentRoot"; \
    fi

# 不要なファイルの削除
RUN rm -rf node_modules .git tests

# ポート80を開放
EXPOSE 80

# Apacheをフォアグラウンドで起動
CMD ["apache2-foreground"]
