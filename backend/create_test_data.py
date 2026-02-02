#!/usr/bin/env python
"""
Скрипт для создания тестовых данных NextStore
Запуск: python create_test_data.py
"""

import os
import sys
import uuid
import random
from decimal import Decimal

# Настройка Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

import django
django.setup()

from django.db import transaction
from shop.models import Category, Product


# ═══════════════════════════════════════════════════════════════════════════
# ТЕСТОВЫЕ ДАННЫЕ
# ═══════════════════════════════════════════════════════════════════════════

CATEGORIES = [
    {
        'name': 'Электроника',
        'slug': 'electronics',
    },
    {
        'name': 'Смартфоны',
        'slug': 'smartphones',
    },
    {
        'name': 'Ноутбуки',
        'slug': 'laptops',
    },
    {
        'name': 'Одежда',
        'slug': 'clothing',
    },
    {
        'name': 'Обувь',
        'slug': 'shoes',
    },
    {
        'name': 'Аксессуары',
        'slug': 'accessories',
    },
    {
        'name': 'Часы',
        'slug': 'watches',
    },
    {
        'name': 'Спорт',
        'slug': 'sports',
    },
]

PRODUCTS = [
    # Электроника
    {
        'name': 'Беспроводные наушники Pro',
        'category_slug': 'electronics',
        'price': '450.00',
        'stock': 25,
        'description': 'Высококачественные беспроводные наушники с активным шумоподавлением. Время работы до 30 часов. Bluetooth 5.0.',
    },
    {
        'name': 'Портативная колонка Boom',
        'category_slug': 'electronics',
        'price': '280.00',
        'stock': 15,
        'description': 'Мощная портативная колонка с защитой от воды IPX7. Глубокий бас и чистый звук.',
    },
    {
        'name': 'Умные часы Fitness Pro',
        'category_slug': 'electronics',
        'price': '650.00',
        'stock': 20,
        'description': 'Умные часы с мониторингом здоровья, GPS и NFC. Водонепроницаемость 5ATM.',
    },
    {
        'name': 'Внешний аккумулятор 20000mAh',
        'category_slug': 'electronics',
        'price': '180.00',
        'stock': 50,
        'description': 'Мощный повербанк с быстрой зарядкой. 2 USB выхода + Type-C.',
    },
    {
        'name': 'Беспроводная зарядка Fast',
        'category_slug': 'electronics',
        'price': '120.00',
        'stock': 30,
        'description': 'Быстрая беспроводная зарядка 15W. Совместима со всеми Qi устройствами.',
    },
    
    # Смартфоны
    {
        'name': 'Смартфон Galaxy Ultra',
        'category_slug': 'smartphones',
        'price': '4500.00',
        'stock': 10,
        'description': 'Флагманский смартфон с камерой 200MP. 12GB RAM, 512GB памяти. AMOLED дисплей 6.8".',
    },
    {
        'name': 'Смартфон iPhone Pro Max',
        'category_slug': 'smartphones',
        'price': '5200.00',
        'stock': 8,
        'description': 'Премиальный смартфон с чипом A17 Pro. Титановый корпус. Камера 48MP.',
    },
    {
        'name': 'Смартфон Xiaomi Note',
        'category_slug': 'smartphones',
        'price': '1200.00',
        'stock': 35,
        'description': 'Отличный смартфон по доступной цене. 8GB RAM, 256GB памяти. Батарея 5000mAh.',
    },
    {
        'name': 'Смартфон Pixel Pro',
        'category_slug': 'smartphones',
        'price': '3800.00',
        'stock': 12,
        'description': 'Лучшая камера на Android. Чистый Android с быстрыми обновлениями.',
    },
    {
        'name': 'Смартфон OnePlus Nord',
        'category_slug': 'smartphones',
        'price': '1800.00',
        'stock': 20,
        'description': 'Быстрый и стильный смартфон. 90Hz дисплей, быстрая зарядка 65W.',
    },
    
    # Ноутбуки
    {
        'name': 'MacBook Pro 14"',
        'category_slug': 'laptops',
        'price': '12000.00',
        'stock': 5,
        'description': 'Профессиональный ноутбук с чипом M3 Pro. 18GB RAM, 512GB SSD. Retina дисплей.',
    },
    {
        'name': 'Ноутбук Dell XPS 15',
        'category_slug': 'laptops',
        'price': '8500.00',
        'stock': 7,
        'description': 'Премиальный Windows ноутбук. Intel Core i7, 16GB RAM, RTX 4060.',
    },
    {
        'name': 'Ноутбук ASUS ROG',
        'category_slug': 'laptops',
        'price': '9500.00',
        'stock': 6,
        'description': 'Игровой ноутбук с RTX 4070. 32GB RAM, 1TB SSD. Дисплей 240Hz.',
    },
    {
        'name': 'Ноутбук Lenovo ThinkPad',
        'category_slug': 'laptops',
        'price': '5500.00',
        'stock': 10,
        'description': 'Бизнес ноутбук с отличной клавиатурой. Intel Core i5, 16GB RAM.',
    },
    {
        'name': 'Ноутбук HP Pavilion',
        'category_slug': 'laptops',
        'price': '3200.00',
        'stock': 15,
        'description': 'Универсальный ноутбук для работы и учёбы. AMD Ryzen 5, 8GB RAM.',
    },
    
    # Одежда
    {
        'name': 'Куртка зимняя Premium',
        'category_slug': 'clothing',
        'price': '850.00',
        'stock': 20,
        'description': 'Тёплая зимняя куртка с натуральным пухом. Водоотталкивающая ткань.',
    },
    {
        'name': 'Худи Classic Black',
        'category_slug': 'clothing',
        'price': '280.00',
        'stock': 40,
        'description': 'Стильное худи из 100% хлопка. Удобный крой, качественная ткань.',
    },
    {
        'name': 'Джинсы Slim Fit',
        'category_slug': 'clothing',
        'price': '350.00',
        'stock': 30,
        'description': 'Классические джинсы slim fit. Премиальный деним, идеальная посадка.',
    },
    {
        'name': 'Футболка Basic White',
        'category_slug': 'clothing',
        'price': '120.00',
        'stock': 100,
        'description': 'Базовая белая футболка. 100% хлопок, плотность 180 г/м².',
    },
    {
        'name': 'Рубашка Oxford Blue',
        'category_slug': 'clothing',
        'price': '420.00',
        'stock': 25,
        'description': 'Классическая рубашка Oxford. Идеальна для офиса и повседневной носки.',
    },
    
    # Обувь
    {
        'name': 'Кроссовки Air Max',
        'category_slug': 'shoes',
        'price': '680.00',
        'stock': 18,
        'description': 'Культовые кроссовки с воздушной подушкой. Комфорт и стиль.',
    },
    {
        'name': 'Кроссовки Running Pro',
        'category_slug': 'shoes',
        'price': '520.00',
        'stock': 25,
        'description': 'Профессиональные беговые кроссовки. Лёгкие и дышащие.',
    },
    {
        'name': 'Ботинки Chelsea',
        'category_slug': 'shoes',
        'price': '750.00',
        'stock': 12,
        'description': 'Стильные ботинки челси из натуральной кожи. Классический дизайн.',
    },
    {
        'name': 'Кеды Canvas White',
        'category_slug': 'shoes',
        'price': '280.00',
        'stock': 40,
        'description': 'Классические белые кеды. Универсальная обувь на каждый день.',
    },
    {
        'name': 'Сандалии Comfort',
        'category_slug': 'shoes',
        'price': '320.00',
        'stock': 30,
        'description': 'Удобные сандалии для лета. Анатомическая стелька.',
    },
    
    # Аксессуары
    {
        'name': 'Рюкзак Urban',
        'category_slug': 'accessories',
        'price': '380.00',
        'stock': 22,
        'description': 'Стильный городской рюкзак. Отделение для ноутбука 15". Водоотталкивающая ткань.',
    },
    {
        'name': 'Кошелёк Leather',
        'category_slug': 'accessories',
        'price': '250.00',
        'stock': 35,
        'description': 'Кошелёк из натуральной кожи. RFID защита. Компактный размер.',
    },
    {
        'name': 'Солнцезащитные очки Aviator',
        'category_slug': 'accessories',
        'price': '420.00',
        'stock': 20,
        'description': 'Классические очки-авиаторы. UV400 защита. Металлическая оправа.',
    },
    {
        'name': 'Ремень Classic',
        'category_slug': 'accessories',
        'price': '180.00',
        'stock': 45,
        'description': 'Кожаный ремень с классической пряжкой. Ширина 3.5 см.',
    },
    {
        'name': 'Шапка Beanie',
        'category_slug': 'accessories',
        'price': '95.00',
        'stock': 60,
        'description': 'Тёплая шапка-бини. Акрил + шерсть. Универсальный размер.',
    },
    
    # Часы
    {
        'name': 'Часы Chronograph Steel',
        'category_slug': 'watches',
        'price': '1200.00',
        'stock': 8,
        'description': 'Мужские часы с хронографом. Корпус из нержавеющей стали. Водозащита 100м.',
    },
    {
        'name': 'Часы Minimalist Gold',
        'category_slug': 'watches',
        'price': '850.00',
        'stock': 12,
        'description': 'Элегантные часы в минималистичном стиле. Позолоченный корпус.',
    },
    {
        'name': 'Часы Sport Digital',
        'category_slug': 'watches',
        'price': '350.00',
        'stock': 25,
        'description': 'Спортивные цифровые часы. Секундомер, таймер, подсветка. Водозащита 50м.',
    },
    {
        'name': 'Часы Classic Leather',
        'category_slug': 'watches',
        'price': '680.00',
        'stock': 15,
        'description': 'Классические часы с кожаным ремешком. Швейцарский механизм.',
    },
    
    # Спорт
    {
        'name': 'Коврик для йоги Pro',
        'category_slug': 'sports',
        'price': '180.00',
        'stock': 30,
        'description': 'Профессиональный коврик для йоги. Толщина 6мм, нескользящее покрытие.',
    },
    {
        'name': 'Гантели 10кг (пара)',
        'category_slug': 'sports',
        'price': '320.00',
        'stock': 20,
        'description': 'Гантели с неопреновым покрытием. Удобный хват, не повреждают пол.',
    },
    {
        'name': 'Скакалка Speed',
        'category_slug': 'sports',
        'price': '85.00',
        'stock': 50,
        'description': 'Скоростная скакалка с подшипниками. Регулируемая длина.',
    },
    {
        'name': 'Фитнес-браслет Track',
        'category_slug': 'sports',
        'price': '280.00',
        'stock': 25,
        'description': 'Фитнес-браслет с пульсометром. Мониторинг сна, шагомер, уведомления.',
    },
    {
        'name': 'Бутылка для воды 1L',
        'category_slug': 'sports',
        'price': '65.00',
        'stock': 80,
        'description': 'Спортивная бутылка из тритана. BPA-free, не впитывает запахи.',
    },
    
    # Дополнительные товары для разнообразия
    {
        'name': 'Клавиатура Mechanical RGB',
        'category_slug': 'electronics',
        'price': '380.00',
        'stock': 18,
        'description': 'Механическая клавиатура с RGB подсветкой. Переключатели Cherry MX.',
    },
    {
        'name': 'Мышь Gaming Pro',
        'category_slug': 'electronics',
        'price': '220.00',
        'stock': 25,
        'description': 'Игровая мышь с DPI до 16000. 8 программируемых кнопок.',
    },
    {
        'name': 'Веб-камера HD 1080p',
        'category_slug': 'electronics',
        'price': '180.00',
        'stock': 30,
        'description': 'Веб-камера для видеозвонков. Автофокус, встроенный микрофон.',
    },
    {
        'name': 'Толстовка Oversize',
        'category_slug': 'clothing',
        'price': '320.00',
        'stock': 35,
        'description': 'Модная толстовка оверсайз. Мягкий флис внутри.',
    },
    {
        'name': 'Спортивные штаны Jogger',
        'category_slug': 'clothing',
        'price': '280.00',
        'stock': 40,
        'description': 'Удобные джоггеры для спорта и отдыха. Эластичный пояс и манжеты.',
    },
]

# Товары с нулевым остатком (для тестирования)
OUT_OF_STOCK_PRODUCTS = [
    {
        'name': 'iPhone 15 Pro Max 1TB',
        'category_slug': 'smartphones',
        'price': '7500.00',
        'stock': 0,
        'description': 'Топовая модель с максимальной памятью. Временно нет в наличии.',
    },
    {
        'name': 'MacBook Pro 16" M3 Max',
        'category_slug': 'laptops',
        'price': '18000.00',
        'stock': 0,
        'description': 'Самый мощный ноутбук Apple. Ожидается поставка.',
    },
]


# ═══════════════════════════════════════════════════════════════════════════
# ФУНКЦИИ СОЗДАНИЯ
# ═══════════════════════════════════════════════════════════════════════════

def create_categories():
    """Создание категорий"""
    print("\n📁 Создание категорий...")
    created = 0
    updated = 0
    
    for cat_data in CATEGORIES:
        category, is_created = Category.objects.update_or_create(
            slug=cat_data['slug'],
            defaults={
                'name': cat_data['name'],
                'is_active': True,
            }
        )
        if is_created:
            created += 1
            print(f"   ✅ Создана: {category.name}")
        else:
            updated += 1
            print(f"   🔄 Обновлена: {category.name}")
    
    print(f"\n   Итого: создано {created}, обновлено {updated}")
    return Category.objects.count()


def create_products():
    """Создание товаров"""
    print("\n📦 Создание товаров...")
    created = 0
    skipped = 0
    
    all_products = PRODUCTS + OUT_OF_STOCK_PRODUCTS
    
    for prod_data in all_products:
        try:
            category = Category.objects.get(slug=prod_data['category_slug'])
        except Category.DoesNotExist:
            print(f"   ⚠️ Категория не найдена: {prod_data['category_slug']}")
            skipped += 1
            continue
        
        # Проверяем существует ли товар с таким названием
        if Product.objects.filter(name=prod_data['name']).exists():
            print(f"   ⏭️ Пропущен (уже есть): {prod_data['name']}")
            skipped += 1
            continue
        
        product = Product.objects.create(
            id=uuid.uuid4(),
            name=prod_data['name'],
            category=category,
            price=Decimal(prod_data['price']),
            stock=prod_data['stock'],
            description=prod_data['description'],
            is_active=True,
        )
        created += 1
        
        stock_status = "🟢" if prod_data['stock'] > 0 else "🔴"
        print(f"   {stock_status} Создан: {product.name} ({product.price} TMT, остаток: {product.stock})")
    
    print(f"\n   Итого: создано {created}, пропущено {skipped}")
    return Product.objects.count()


def show_statistics():
    """Показать статистику"""
    print("\n" + "=" * 60)
    print("📊 СТАТИСТИКА БАЗЫ ДАННЫХ")
    print("=" * 60)
    
    print(f"\n   📁 Категорий: {Category.objects.count()}")
    print(f"   📦 Товаров всего: {Product.objects.count()}")
    print(f"   🟢 В наличии: {Product.objects.filter(stock__gt=0).count()}")
    print(f"   🔴 Нет в наличии: {Product.objects.filter(stock=0).count()}")
    
    print("\n   📁 Товаров по категориям:")
    for cat in Category.objects.all():
        count = Product.objects.filter(category=cat).count()
        print(f"      • {cat.name}: {count}")
    
    # Ценовая статистика
    from django.db.models import Min, Max, Avg
    stats = Product.objects.aggregate(
        min_price=Min('price'),
        max_price=Max('price'),
        avg_price=Avg('price'),
    )
    
    print(f"\n   💰 Цены:")
    print(f"      • Минимальная: {stats['min_price']} TMT")
    print(f"      • Максимальная: {stats['max_price']} TMT")
    print(f"      • Средняя: {stats['avg_price']:.2f} TMT")
    
    print("\n" + "=" * 60)


def clear_all_data():
    """Очистить все данные (кроме пользователей)"""
    print("\n🗑️ Очистка данных...")
    
    from shop.models import Order, OrderItem, Favorite
    
    # Удаляем в правильном порядке (из-за foreign keys)
    order_items = OrderItem.objects.count()
    OrderItem.objects.all().delete()
    print(f"   ✅ Удалено позиций заказов: {order_items}")
    
    orders = Order.objects.count()
    Order.objects.all().delete()
    print(f"   ✅ Удалено заказов: {orders}")
    
    favorites = Favorite.objects.count()
    Favorite.objects.all().delete()
    print(f"   ✅ Удалено избранного: {favorites}")
    
    products = Product.objects.count()
    Product.objects.all().delete()
    print(f"   ✅ Удалено товаров: {products}")
    
    categories = Category.objects.count()
    Category.objects.all().delete()
    print(f"   ✅ Удалено категорий: {categories}")
    
    print("\n   ✨ База данных очищена!")


# ═══════════════════════════════════════════════════════════════════════════
# ГЛАВНОЕ МЕНЮ
# ═══════════════════════════════════════════════════════════════════════════

def main():
    print("\n" + "=" * 60)
    print("🛒 NEXTSTORE - ГЕНЕРАТОР ТЕСТОВЫХ ДАННЫХ")
    print("=" * 60)
    
    print("""
    Выберите действие:
    
    1. ➕ Добавить тестовые данные (категории + товары)
    2. 📊 Показать статистику
    3. 🗑️ Очистить ВСЕ данные (кроме пользователей)
    4. 🔄 Пересоздать всё (очистить + создать заново)
    0. ❌ Выход
    """)
    
    try:
        choice = input("    Ваш выбор (0-4): ").strip()
    except KeyboardInterrupt:
        print("\n\n   👋 До свидания!")
        sys.exit(0)
    
    if choice == '1':
        with transaction.atomic():
            create_categories()
            create_products()
        show_statistics()
        
    elif choice == '2':
        show_statistics()
        
    elif choice == '3':
        confirm = input("\n    ⚠️ Вы уверены? Все данные будут удалены! (да/нет): ").strip().lower()
        if confirm in ['да', 'yes', 'y', 'д']:
            with transaction.atomic():
                clear_all_data()
        else:
            print("\n    ❌ Отменено")
            
    elif choice == '4':
        confirm = input("\n    ⚠️ Вы уверены? Все данные будут пересозданы! (да/нет): ").strip().lower()
        if confirm in ['да', 'yes', 'y', 'д']:
            with transaction.atomic():
                clear_all_data()
                create_categories()
                create_products()
            show_statistics()
        else:
            print("\n    ❌ Отменено")
            
    elif choice == '0':
        print("\n   👋 До свидания!")
        sys.exit(0)
        
    else:
        print("\n    ⚠️ Неверный выбор!")
    
    # Спросить что делать дальше
    print()
    again = input("    Выполнить ещё действие? (да/нет): ").strip().lower()
    if again in ['да', 'yes', 'y', 'д']:
        main()
    else:
        print("\n   👋 До свидания!")


if __name__ == '__main__':
    main()