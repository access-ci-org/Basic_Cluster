import rabbit_config as rcfg

Head = f"""From: {rcfg.Sender_alias} <{rcfg.Sender}>
To: <{{{{ to }}}}>
Subject: {rcfg.Subject}
"""

Body = f"""
Hi {{{{ username }}}}
Your account has been set up with:

============================
User ID:  {{{{ username }}}}
============================

If you have any questions, please visit:
{rcfg.Info_url}

or email at {rcfg.Admin_email}

Cheers,
"""

Whole_mail = Head + Body

UserReportHead = f"""From: {rcfg.Sender_alias} <{rcfg.Sender}>
To: <{rcfg.Admin_email}>
Subject: RC Account Creation Report: {{{{ fullname }}}}, {{{{ username }}}} """
