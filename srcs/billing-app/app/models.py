from sqlalchemy import Column, Integer, Numeric, String
from app.database import Base


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(String(50), nullable=False)
    number_of_items = Column(Integer, nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
