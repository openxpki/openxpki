# New ports collection makefile for:	p5-openxpki-client
# Date created:				03 Oct 2006
# Whom:					svysh
#
# $FreeBSD: ports/security/p5-openxpki-client/Makefile,v 1.8 2009/01/22 02:48:06 araujo Exp $
#

PORTNAME=	openxpki-client
PORTVERSION=	0.9.1284
CATEGORIES=	security perl5
MASTER_SITES=	http://www7.openxpki.org/lastmidnight/ SF/openxpki/openxpki/0.9.1300
PKGNAMEPREFIX=	p5-
DISTNAME=	OpenXPKI-Client-${PORTVERSION}
DIST_SUBDIR=	openxpki

MAINTAINER=	svysh@pn.sinp.msu.ru
COMMENT=	Perl based trustcenter software for PKI: base class for actual clients

LICENSE=	AL2

BUILD_DEPENDS=	\
	${SITE_PERL}/${PERL_ARCH}/OpenXPKI.pm:${PORTSDIR}/security/p5-openxpki
RUN_DEPENDS=	${BUILD_DEPENDS}

MAN3=	OpenXPKI::Client.3 \
	OpenXPKI::Client::API.3
USE_GMAKE=	yes
PERL_CONFIGURE=	yes

.include <bsd.port.mk>
