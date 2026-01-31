# Django Backend Setup for Dynamic Subscription Plans

## Steps to Complete Setup

### 1. Run Migrations
After adding the new models (`SubscriptionPlan` and `Subscription`), run:

```bash
python manage.py makemigrations users
python manage.py migrate
```

### 2. Add URLs to Main URL Configuration
Make sure the users app URLs are included in your main `urls.py`:

```python
# In your main urls.py (usually in the project root)
urlpatterns = [
    # ... other patterns
    path('api/users/', include('users.urls')),
    # ... other patterns
]
```

### 3. Create Subscription Plans via Django Admin
1. Go to Django admin panel
2. Add `SubscriptionPlan` entries with:
   - `name`: Plan name (e.g., "1 моҳ", "3 моҳ", "1 сол")
   - `price`: Price in somoni (e.g., 50.00)
   - `days`: Number of days (e.g., 30, 90, 365)
   - `is_active`: Set to True

### 4. API Endpoints
- **GET** `/api/users/subscription-plans/` - Get list of active subscription plans (public)
- **POST** `/api/users/purchase-subscription/` - Purchase a subscription (authenticated)
  - Body: `{"plan_id": 1}`

### 5. Purchase Flow
When a user purchases a subscription:
1. System validates user balance against plan price
2. Deducts balance from user account
3. Calculates `expires_at` based on plan's `days` field
4. If user has existing active subscription, extends from current expiration date
5. Otherwise, starts from current date

## Notes
- The `PurchaseSubscriptionView` automatically handles extending existing subscriptions
- Balance validation is performed before purchase
- Old subscriptions are deactivated when a new one is purchased

