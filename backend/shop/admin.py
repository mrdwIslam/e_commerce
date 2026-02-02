# backend/shop/admin.py
"""
Django Admin конфигурация для NextStore
"""

from django.contrib import admin
from django.utils.html import format_html
from .models import Category, Product, Profile, Order, OrderItem, Favorite


# ===========================================
# INLINE MODELS
# ===========================================

class OrderItemInline(admin.TabularInline):
    """Позиции заказа (inline в заказе)"""
    model = OrderItem
    extra = 0
    readonly_fields = ['product', 'product_name', 'price', 'quantity', 'get_cost']
    can_delete = False
    
    def get_cost(self, obj):
        return f"{obj.get_cost()} TMT"
    get_cost.short_description = "Сумма"
    
    def has_add_permission(self, request, obj=None):
        return False


# ===========================================
# CATEGORY ADMIN
# ===========================================

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug', 'products_count', 'is_active']
    list_filter = ['is_active']
    list_editable = ['is_active']
    search_fields = ['name', 'slug']
    prepopulated_fields = {'slug': ('name',)}
    ordering = ['name']
    
    def products_count(self, obj):
        return obj.products.filter(is_active=True).count()
    products_count.short_description = "Товаров"


# ===========================================
# PRODUCT ADMIN
# ===========================================

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = [
        'name', 
        'category',
        'price',
        'stock',
        'is_active',
        'created'
    ]
    list_filter = ['category', 'is_active', 'created']
    list_editable = ['price', 'stock', 'is_active']
    search_fields = ['name', 'description']
    readonly_fields = ['id', 'created', 'updated']
    ordering = ['-created']
    date_hierarchy = 'created'
    list_per_page = 25
    
    fieldsets = (
        ('Основное', {
            'fields': ('id', 'name', 'category', 'description')
        }),
        ('Цена и наличие', {
            'fields': ('price', 'stock', 'is_active')
        }),
        ('Изображение', {
            'fields': ('image',)
        }),
        ('Даты', {
            'fields': ('created', 'updated'),
            'classes': ('collapse',)
        }),
    )


# ===========================================
# PROFILE ADMIN
# ===========================================

@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'get_email', 'phone', 'get_status', 'otp_code']
    list_filter = ['user__is_active']
    search_fields = ['user__username', 'user__email', 'phone']
    readonly_fields = ['user', 'otp_code', 'otp_created_at']
    ordering = ['-user__date_joined']
    
    def get_email(self, obj):
        return obj.user.email
    get_email.short_description = "Email"
    
    def get_status(self, obj):
        if obj.user.is_active:
            return format_html('<span style="color: green;">✓ Активен</span>')
        return format_html('<span style="color: red;">✗ Неактивен</span>')
    get_status.short_description = "Статус"


# ===========================================
# ORDER ADMIN
# ===========================================

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = [
        'order_number',
        'get_customer',
        'phone',
        'status',
        'total_amount',
        'items_count',
        'created_at'
    ]
    list_filter = ['status', 'created_at']
    list_editable = ['status']
    search_fields = ['order_number', 'first_name', 'last_name', 'phone', 'email']
    readonly_fields = [
        'order_number', 
        'user',
        'total_amount', 
        'created_at', 
        'updated_at'
    ]
    ordering = ['-created_at']
    date_hierarchy = 'created_at'
    list_per_page = 25
    inlines = [OrderItemInline]
    
    fieldsets = (
        ('Заказ', {
            'fields': ('order_number', 'status', 'user')
        }),
        ('Получатель', {
            'fields': ('first_name', 'last_name', 'phone', 'email', 'address')
        }),
        ('Сумма и комментарий', {
            'fields': ('total_amount', 'note')
        }),
        ('Даты', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['mark_confirmed', 'mark_processing', 'mark_shipped', 'mark_delivered', 'mark_cancelled']
    
    def get_customer(self, obj):
        return f"{obj.first_name} {obj.last_name}"
    get_customer.short_description = "Клиент"
    
    def items_count(self, obj):
        return obj.items.count()
    items_count.short_description = "Позиций"
    
    @admin.action(description="✓ Подтвердить заказы")
    def mark_confirmed(self, request, queryset):
        queryset.update(status='confirmed')
    
    @admin.action(description="⚙ В обработку")
    def mark_processing(self, request, queryset):
        queryset.update(status='processing')
    
    @admin.action(description="📦 Отправлено")
    def mark_shipped(self, request, queryset):
        queryset.update(status='shipped')
    
    @admin.action(description="✓ Доставлено")
    def mark_delivered(self, request, queryset):
        queryset.update(status='delivered')
    
    @admin.action(description="✗ Отменить заказы")
    def mark_cancelled(self, request, queryset):
        for order in queryset.filter(status__in=['pending', 'confirmed']):
            for item in order.items.all():
                if item.product:
                    item.product.stock += item.quantity
                    item.product.save()
        queryset.update(status='cancelled')


# ===========================================
# ORDER ITEM ADMIN
# ===========================================

@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ['order', 'product_name', 'price', 'quantity', 'get_cost']
    list_filter = ['order__status', 'order__created_at']
    search_fields = ['order__order_number', 'product_name']
    ordering = ['-order__created_at']
    
    def get_cost(self, obj):
        return f"{obj.get_cost()} TMT"
    get_cost.short_description = "Сумма"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False


# ===========================================
# FAVORITE ADMIN
# ===========================================

@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ['user', 'product', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'user__email', 'product__name']
    ordering = ['-created_at']
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False


# ===========================================
# ADMIN SITE CUSTOMIZATION
# ===========================================
admin.site.site_header = "NEXTSTORE Admin"
admin.site.site_title = "NextStore"
admin.site.index_title = "Панель управления магазином"