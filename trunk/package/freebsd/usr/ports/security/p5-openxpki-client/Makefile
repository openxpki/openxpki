# New ports collection makefile for:	p5-openxpki-client
# Date created:				03 Oct 2006
# Whom:					svysh
#
# $FreeBSD: ports/security/p5-openxpki-client/Makefile,v 1.2 2007/02/03 09:49:16 miwi Exp $
#

PORTNAME=	openxpki-client
PORTVERSION=	0.9.651
CATEGORIES=	security perl5
MASTER_SITES=	${MASTER_SITE_SOURCEFORGE}
MASTER_SITE_SUBDIR=	openxpki
PKGNAMEPREFIX=	p5-
DISTNAME=	OpenXPKI-Client-${PORTVERSION}
DIST_SUBDIR=	openxpki

MAINTAINER=	svysh@cryptocom.ru
COMMENT=	Perl based trustcenter software for PKI: base class for actual clients

BUILD_DEPENDS=	\
	${SITE_PERL}/${PERL_ARCH}/OpenXPKI.pm:${PORTSDIR}/security/p5-openxpki
RUN_DEPENDS=	${BUILD_DEPENDS}

MAN3=	OpenXPKI::Client.3 \
	OpenXPKI::Client::API.3
USE_PERL5=	yes
USE_GMAKE=	yes
PERL_CONFIGURE=	yes

.include <bsd.port.mk>
