FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY hoobird_rules.py /app/hoobird_rules.py
COPY hoobird_policy_api /app/hoobird_policy_api
ENV PYTHONPATH=/app
EXPOSE 8018
CMD ["uvicorn", "hoobird_policy_api.main:app", "--host", "127.0.0.1", "--port", "18018"]
