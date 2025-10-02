import uuid
import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

# --------------------------------------------------------------------------
# 1. Product Data Models (Pydantic Schemas)
# Reworked to match the fields expected by the user's Dart model.
# --------------------------------------------------------------------------

class ProductBase(BaseModel):
    """Base model for product data (used for creation and updating)."""
    name: str = Field(..., example="Chicken Biryani", min_length=3, description="The name of the menu item.")
    # Dart expects 'price' to be converted from a string, so we send a float.
    price: float = Field(..., gt=0, example=150.00, description="The selling price of the product.")
    category: str = Field(..., example="Main Course", description="The product category.")
    
    # NEW FIELD required by Dart model
    stock_quantity: int = Field(..., ge=0, example=100, description="The current stock quantity.")

class ProductCreate(ProductBase):
    """Model used when creating a new product."""
    pass

class ProductUpdate(ProductBase):
    """Model used when updating an existing product (all fields are optional)."""
    name: Optional[str] = Field(None)
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = Field(None)
    stock_quantity: Optional[int] = Field(None, ge=0)

class Product(ProductBase):
    """The complete Product model, including the unique ID and timestamps."""
    # Reworked ID field to be 'id' to match the Dart model
    id: str = Field(..., example=str(uuid.uuid4()), description="Unique identifier for the product.")
    
    # NEW FIELDS required by Dart model (sent as ISO 8601 strings)
    created_at: str = Field(..., example=datetime.datetime.now().isoformat(), description="Timestamp of creation (ISO format).")
    updated_at: str = Field(..., example=datetime.datetime.now().isoformat(), description="Timestamp of last update (ISO format).")

    class Config:
        from_attributes = True


# --------------------------------------------------------------------------
# 2. FastAPI Application Setup and In-Memory Storage
# --------------------------------------------------------------------------

app = FastAPI(
    title="Mpepo Kitchen Product API",
    description="CRUD endpoints matching the required Dart Product model structure.",
    version="1.0.0",
)

# Simple in-memory database substitute
# Maps product ID (str) -> Product object
products_db: dict[str, Product] = {}


# --------------------------------------------------------------------------
# 3. Utility Functions
# --------------------------------------------------------------------------

def get_iso_now() -> str:
    """Returns the current UTC time formatted as an ISO 8601 string."""
    return datetime.datetime.now(datetime.UTC).isoformat()

# --------------------------------------------------------------------------
# 4. CRUD Endpoints Implementation
# --------------------------------------------------------------------------

@app.post("/products", response_model=Product, status_code=201, tags=["Products"])
async def create_product(product: ProductCreate):
    """
    **C**reate a new product, ensuring all required fields for the Dart model are included.
    """
    product_id = str(uuid.uuid4())
    now_iso = get_iso_now()

    new_product = Product(
        id=product_id, 
        created_at=now_iso,
        updated_at=now_iso,
        **product.model_dump()
    )
    products_db[product_id] = new_product
    return new_product

@app.get("/products", response_model=List[Product], tags=["Products"])
async def read_all_products(category: Optional[str] = None):
    """
    **R**ead all products. The response includes 'id', 'stock_quantity', and timestamps.
    """
    products_list = list(products_db.values())
    
    # Apply category filter
    if category:
        products_list = [p for p in products_list if p.category.lower() == category.lower()]

    return products_list

@app.get("/products/{product_id}", response_model=Product, tags=["Products"])
async def read_product_by_id(product_id: str):
    """
    **R**ead a single product by its unique ID ('id').
    """
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    return products_db[product_id]

@app.put("/products/{product_id}", response_model=Product, tags=["Products"])
async def update_product(product_id: str, product_update: ProductUpdate):
    """
    **U**pdate an existing product. Updates the 'updated_at' timestamp.
    """
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")

    existing_product = products_db[product_id]
    existing_data = existing_product.model_dump()
    update_data = product_update.model_dump(exclude_unset=True)

    # Apply updates
    updated_item = existing_data.copy()
    updated_item.update(update_data)
    
    # Update the timestamp
    updated_item['updated_at'] = get_iso_now()

    products_db[product_id] = Product(**updated_item)
    return products_db[product_id]

@app.delete("/products/{product_id}", status_code=204, tags=["Products"])
async def delete_product(product_id: str):
    """
    **D**elete a product.
    """
    if product_id not in products_db:
        raise HTTPException(status_code=404, detail="Product not found")
    
    del products_db[product_id]
    return {"message": "Product deleted successfully"}

# --------------------------------------------------------------------------
# 5. Example Usage for Testing (Admin)
# --------------------------------------------------------------------------

@app.get("/db-status", tags=["Admin"])
async def get_db_status():
    """Shows the current in-memory database content (for debugging)."""
    return {"product_count": len(products_db), "data": products_db}

@app.post("/seed-data", status_code=201, tags=["Admin"])
async def seed_data():
    """Adds sample products to the database for testing purposes."""
    global products_db
    products_db.clear()
    
    now_iso = get_iso_now()

    products_to_add = [
        ProductCreate(name="Jollof Rice", price=180.00, category="Main Course", stock_quantity=50),
        ProductCreate(name="Mandazi", price=50.00, category="Snack", stock_quantity=200),
        ProductCreate(name="Chapati", price=40.00, category="Side Dish", stock_quantity=75),
    ]

    for product_data in products_to_add:
        product_id = str(uuid.uuid4())
        products_db[product_id] = Product(
            id=product_id, 
            created_at=now_iso,
            updated_at=now_iso,
            **product_data.model_dump()
        )
    
    return {"message": f"{len(products_to_add)} products seeded successfully."}
