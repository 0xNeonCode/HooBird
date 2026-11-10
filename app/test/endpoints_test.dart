// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/endpoints.dart';
import 'package:hoobird/policy_api.dart';

void main() {
  test('defaults stay on loopback when no dart-define is set', () {
    expect(buildHomeserver, loopbackHomeserver);
    expect(buildPolicyUrl, loopbackPolicyUrl);
    expect(buildEndpointsPinned, isFalse);
    expect(resolvedEndpoint('http://10.0.2.2:18008', loopbackHomeserver), loopbackHomeserver);
    expect(resolvedEndpoint(null, loopbackPolicyUrl), loopbackPolicyUrl);
    expect(
      resolvedEndpoint('http://127.0.0.1:18018', loopbackPolicyUrl),
      'http://127.0.0.1:18018',
    );
    expect(sameEndpoint('http://127.0.0.1:18008', 'http://127.0.0.1:18008/'), isTrue);
    expect(
      sameEndpoint('https://hoobird.0xneoncode.de', 'https://hoobird.0xneoncode.de/policy'),
      isFalse,
    );
  });

  test('cleartext is rejected off loopback and a password in the URL is rejected', () {
    expect(endpointRejection('http://127.0.0.1:18008'), isNull);
    expect(endpointRejection('http://localhost:18018'), isNull);
    expect(endpointRejection('http://[::1]:18008'), isNull);
    expect(endpointRejection('https://hoobird.0xneoncode.de'), isNull);
    expect(endpointRejection('https://hoobird.0xneoncode.de/policy'), isNull);
    expect(endpointRejection('http://hoobird.0xneoncode.de'), isNotNull);
    expect(endpointRejection('http://10.0.2.2:18008'), isNotNull);
    expect(endpointRejection('https://user:secret@hoobird.0xneoncode.de'), isNotNull);
    expect(
      () => PolicyApi('http://hoobird.0xneoncode.de'),
      throwsA(isA<PolicyException>()),
    );
  });

  test('policy prefix is joined and the loopback path stays at the root', () {
    expect(
      policyRequestUri('http://127.0.0.1:18018', '/_hoobird/v1/login').toString(),
      'http://127.0.0.1:18018/_hoobird/v1/login',
    );
    expect(
      policyRequestUri(
        'https://hoobird.0xneoncode.de/policy/',
        '/_hoobird/v1/directory',
        query: {'q': 'mara'},
      ).toString(),
      'https://hoobird.0xneoncode.de/policy/_hoobird/v1/directory?q=mara',
    );
    expect(
      policyRequestUri(
        'https://hoobird.0xneoncode.de/policy',
        '/_hoobird/v1/children/@child:example/approvals',
      ).path,
      '/policy/_hoobird/v1/children/@child:example/approvals',
    );
  });
}
