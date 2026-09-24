import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

_firebase_initialized = False


def init_firebase() -> bool:
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials

        # Service account key stored as secret, not in repo per Phase 3 spec
        # Supports: GOOGLE_APPLICATION_CREDENTIALS path, or FIREBASE_SERVICE_ACCOUNT_JSON env var (raw JSON)
        cred_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        cred = None
        if cred_json:
            try:
                info = json.loads(cred_json)
                cred = credentials.Certificate(info)
            except Exception as e:
                logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON invalid: %s", e)
                return False
        elif cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
        else:
            # Try default credentials (e.g. GCP metadata) — will fail gracefully if not present
            # For local dev without key, skip init and keep in-app fallback
            logger.info("No Firebase service account found (GOOGLE_APPLICATION_CREDENTIALS / FIREBASE_SERVICE_ACCOUNT_JSON), FCM push disabled — in-app fallback only")
            return False

        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin initialized")
        return True
    except ImportError:
        logger.warning("firebase_admin not installed, FCM push disabled")
        return False
    except Exception as e:
        logger.warning("Firebase init failed: %s", e)
        return False


def get_messaging() -> Any | None:
    try:
        from firebase_admin import messaging

        return messaging
    except Exception:
        return None
