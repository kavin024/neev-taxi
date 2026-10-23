from __future__ import annotations

import logging
from datetime import timedelta

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import OutboxMessage

logger = logging.getLogger("neev.sms")


def send_sms(
    db: Session, *, recipient: str, template: str, body: str
) -> tuple[str, str]:
    """Return (delivery_label, provider_status).

    The outbox adapter never claims an SMS was delivered. It records a clearly
    labelled simulated message so development flows can be audited.
    """
    if settings.sms_provider == "twilio":
        if not (
            settings.twilio_account_sid
            and settings.twilio_auth_token
            and settings.twilio_from_number
        ):
            message = OutboxMessage(
                channel="sms",
                recipient=recipient,
                template=template,
                body=body,
                provider="twilio",
                status="failed",
                error="Twilio is not configured",
            )
            db.add(message)
            db.commit()
            return "failed", "twilio_unconfigured"
        try:
            response = httpx.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{settings.twilio_account_sid}/Messages.json",
                data={
                    "To": recipient,
                    "From": settings.twilio_from_number,
                    "Body": body,
                },
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
                timeout=10.0,
            )
            response.raise_for_status()
            data = response.json()
            message = OutboxMessage(
                channel="sms",
                recipient=recipient,
                template=template,
                body=body,
                provider="twilio",
                status="sent",
                provider_message_id=data.get("sid"),
            )
            db.add(message)
            db.commit()
            return "sms", "sent"
        except Exception as exc:
            logger.warning("sms.twilio_failed", exc_info=True)
            message = OutboxMessage(
                channel="sms",
                recipient=recipient,
                template=template,
                body=body,
                provider="twilio",
                status="failed",
                error=str(exc)[:300],
            )
            db.add(message)
            db.commit()
            return "failed", "twilio_error"

    message = OutboxMessage(
        channel="sms",
        recipient=recipient,
        template=template,
        body=body,
        provider="outbox",
        status="simulated",
    )
    db.add(message)
    db.commit()
    return "outbox_simulated", "simulated"
